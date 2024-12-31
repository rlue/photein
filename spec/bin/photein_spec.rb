require 'spec_helper'
require 'digest'
require 'fileutils'
require 'open3'

require 'mini_exiftool'
require 'mini_magick'
require 'tzinfo'

RSpec.describe 'photein' do
  let(:data_dir) { File.expand_path('../data', __dir__) }
  let(:tmp_dir) { File.expand_path('../tmp', __dir__) }
  let(:source_dir) { "#{tmp_dir}/source" }
  let(:dest_dir) { "#{tmp_dir}/dest" }
  let(:cmd) { %(bin/photein #{options.join(' ')}) }
  let(:options) { ['--source', source_dir, '--library-master', dest_dir] }

  after { FileUtils.rm_rf(tmp_dir) }

  describe 'CLI option validation' do
    before { FileUtils.rm_rf(tmp_dir) }

    context 'with no --source' do
      let(:options) { [] }

      it 'fails' do
        _out, err, status = Open3.capture3(cmd.split.first)

        expect(err.chomp).to eq('photein: no source directory given')
        expect(status.exitstatus).to eq(1)
      end
    end

    context 'with no --library-*' do
      let(:options) { ['--source', source_dir] }

      it 'fails' do
        _out, err, status = Open3.capture3(cmd)

        expect(err.chomp).to eq('photein: no destination directory given')
        expect(status.exitstatus).to eq(1)
      end
    end

    context 'when --source dir does not exist' do
      it 'fails' do
        _out, err, status = Open3.capture3(cmd)

        expect(err.chomp).to end_with("#{source_dir}: no such directory")
        expect(status.exitstatus).to eq(1)
      end
    end

    context 'when --source dir is empty' do
      before do
        FileUtils.mkdir_p(source_dir)
      end

      it 'fails' do
        _out, err, status = Open3.capture3(cmd)

        expect(err.chomp).to end_with("#{source_dir}: no photos or videos found")
        expect(status.exitstatus).to eq(1)
      end
    end
  end

  describe 'core logic' do
    before do
      FileUtils.mkdir_p(source_dir)
      FileUtils.cp(source_files, source_dir)
    end

    let(:source_files) { Dir["#{data_dir}/basic/*.jpg"] }
    let(:dest_files) { Dir["#{dest_dir}/**/*"].select(&File.method(:file?)).sort }

    context 'when --library-master dir does not exist' do
      it 'automatically creates it' do
        expect { system("#{cmd} >/dev/null") }
          .to change { Dir.exist?(dest_dir) }.from(false).to(true)
      end
    end

    context 'for JPGs with timestamp metadata' do
      it 'moves them from source to dest' do
        expect { system("#{cmd} >/dev/null") }
          .to change { Dir.empty?(source_dir) }.from(false).to(true)

        expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
          #{dest_dir}
          └── 2020
              └── 2020-02-14_225530.jpg
        TREE
      end

      context 'for multiple source files with identical timestamps' do
        let(:source_files) { Dir["#{data_dir}/timestamp_conflict/*.jpg"] }

        it 'adds counters to filenames' do
          system("#{cmd} >/dev/null")

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2018
                ├── 2018-09-01_145650+1.jpg
                ├── 2018-09-01_145650+2.jpg
                └── 2018-09-01_145650.jpg
          TREE
        end
      end

      context 'with --keep option' do
        let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--keep'] }

        it 'copies them from source to dest' do
          expect { system("#{cmd} >/dev/null") }
            .not_to(change { `tree --noreport #{source_dir}` })

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2020
                └── 2020-02-14_225530.jpg
          TREE
        end
      end

      context 'with --dry-run option' do
        let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--dry-run'] }

        it 'is a no-op' do
          expect { system("#{cmd} >/dev/null") }
            .not_to(change { `tree --noreport #{dest_dir}` })

          expect(Dir.exist?(dest_dir)).to be(false)
        end
      end

      context 'with --library-desktop option' do
        let(:options) { ['--source', source_dir, '--library-desktop', dest_dir] }
        let!(:source_sha256) { Digest::SHA256.hexdigest(File.binread(source_files.first)) }
        let(:dest_sha256) { Digest::SHA256.hexdigest(File.binread(dest_files.first)) }

        it 'performs a simple copy' do
          system("#{cmd} >/dev/null")
          expect(source_sha256).to eq(dest_sha256)
        end
      end

      context 'with --library-web option' do
        let(:options) { ['--source', source_dir, '--library-web', dest_dir] }
        let!(:source_resolution) { MiniMagick::Image.new(source_files.first).dimensions.reduce(&:*) }
        let(:dest_resolution) { MiniMagick::Image.new(dest_files.first).dimensions.reduce(&:*) }

        it 'reduces resolution to 2MP' do
          system("#{cmd} >/dev/null")

          expect(source_resolution).to be > (2 * 1024 * 1024)
          expect(dest_resolution).to be <= (2 * 1024 * 1024)
        end
      end

      context 'with --shift-timestamp option' do
        let(:options) do
          [
            '--source', source_dir,
            '--library-master', dest_dir,
            '--shift-timestamp', timestamp_delta
          ]
        end

        let(:source_files) { Dir["#{data_dir}/basic/IMG_20200214_225530.jpg"] }
        let(:timestamp_delta) { '-8' }
        let(:adjusted_timestamp) { Time.new(2020, 2, 14, 14, 55, 30) }
        let(:dest_file) { "#{dest_dir}/#{adjusted_timestamp.strftime('%Y/%F_%H%M%S')}.jpg" }

        it 'applies shift to filename' do
          system("#{cmd} >/dev/null")

          expect(dest_files).to include dest_file
        end

        it 'applies shift to all date tags' do
          system("#{cmd} >/dev/null")

          expect(MiniExiftool.new(dest_file).date_time_original).to eq adjusted_timestamp
          expect(MiniExiftool.new(dest_file).create_date).to eq adjusted_timestamp
          expect(MiniExiftool.new(dest_file).modify_date).to eq adjusted_timestamp
        end

        shared_examples 'invalid value' do |type|
          it "rejects #{type}" do
            _out, err, status = Open3.capture3(cmd)

            expect(err.chomp).to eq('photein: invalid --shift-timestamp option (must be integer)')
            expect(status.exitstatus).to eq(1)
          end
        end

        it_behaves_like 'invalid value', 'alphanumeric strings' do
          let(:timestamp_delta) { 'foo123' }
        end

        it_behaves_like 'invalid value', 'floats' do
          let(:timestamp_delta) { '0.134' }
        end

        it_behaves_like 'invalid value', '%H:%M-formatted strings' do
          let(:timestamp_delta) { '-02:00' }
        end
      end

      context 'with --local-tz option' do
        let(:options) do
          [
            '--source', source_dir,
            '--library-master', dest_dir,
            '--local-tz', tz
          ]
        end

        let(:source_files) { Dir["#{data_dir}/basic/IMG_20200214_225530.jpg"] }
        let(:tz) { 'Europe/Mariehamn' }
        let(:offset) { '+02:00' }
        let(:dest_file) { "#{dest_dir}/2020/2020-02-14_225530.jpg" }

        it 'does not adjust filename' do
          system("#{cmd} >/dev/null")

          expect(dest_files).to include dest_file
        end

        it 'writes OffsetTime* tags' do
          system("#{cmd} >/dev/null")

          expect(MiniExiftool.new(dest_file).offset_time).to eq offset
          expect(MiniExiftool.new(dest_file).offset_time_original).to eq offset
          expect(MiniExiftool.new(dest_file).offset_time_digitized).to eq offset
        end

        shared_examples 'invalid value' do |type|
          it "reject #{type}" do
            _out, err, status = Open3.capture3(cmd)

            expect(err.chomp).to eq("photein: invalid --local-tz option (#{error_msg})")
            expect(status.exitstatus).to eq(1)
          end
        end

        it_behaves_like 'invalid value', 'location-less time zone' do
          let(:tz) { 'Etc/Zulu' }
          let(:error_msg) { 'must reference a location' }
        end

        it_behaves_like 'invalid value', 'unqualified place name' do
          let(:tz) { 'Guernsey' }
          let(:error_msg) { 'must be from IANA tz database' }
        end

        it_behaves_like 'invalid value', 'non-standard format' do
          let(:tz) { 'pacific/pago\\ pago' }
          let(:error_msg) { 'must be from IANA tz database' }
        end
      end
    end

    context 'for DNGs' do
      let(:source_files) { Dir["#{data_dir}/basic/*.DNG"] }

      it 'moves them from source to dest' do
        expect { system("#{cmd} >/dev/null") }
          .to change { Dir.empty?(source_dir) }.from(false).to(true)

        expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
          #{dest_dir}
          └── 2019
              └── 2019-07-07_105018.dng
        TREE
      end

      context 'with --library-desktop option' do
        let(:options) { ['--source', source_dir, '--library-desktop', dest_dir] }

        it 'moves them from source to dest' do
          expect { system("#{cmd} >/dev/null") }
            .to change { Dir.empty?(source_dir) }.from(false).to(true)

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2019
                └── 2019-07-07_105018.dng
          TREE
        end
      end

      context 'with --library-web option' do
        let(:options) { ['--source', source_dir, '--library-web', dest_dir] }

        it 'skips import' do
          expect { system("#{cmd} >/dev/null 2>&1") }
            .not_to(change { `tree --noreport #{source_dir}` })

          expect(Dir.exist?(dest_dir)).to be(false)
        end
      end
    end

    context 'for HEICs' do
      let(:source_files) { Dir["#{data_dir}/basic/*.HEIC"] }

      it 'moves them from source to dest' do
        expect { system("#{cmd} >/dev/null") }
          .to change { Dir.empty?(source_dir) }.from(false).to(true)

        expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
          #{dest_dir}
          └── 2019
              └── 2019-12-01_120213.heic
        TREE
      end

      context 'with --library-desktop option' do
        let(:options) { ['--source', source_dir, '--library-desktop', dest_dir] }

        it 'moves them from source to dest' do
          expect { system("#{cmd} >/dev/null") }
            .to change { Dir.empty?(source_dir) }.from(false).to(true)

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2019
                └── 2019-12-01_120213.heic
          TREE
        end
      end

      context 'with --library-web option' do
        let(:options) { ['--source', source_dir, '--library-web', dest_dir] }
        let!(:source_resolution) { MiniMagick::Image.new(source_files.first).dimensions.reduce(&:*) }
        let(:dest_resolution) { MiniMagick::Image.new(dest_files.first).dimensions.reduce(&:*) }

        it 'converts to a 2MP-max .jpg' do
          system("#{cmd} >/dev/null")

          expect(source_resolution).to be > (2 * 1024 * 1024)
          expect(dest_resolution).to be <= (2 * 1024 * 1024)

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2019
                └── 2019-12-01_120213.jpg
          TREE
        end
      end
    end

    context 'for MP4s with timestamp metadata' do
      context 'and GPS data' do
        let(:source_files) { Dir["#{data_dir}/basic/*.mp4"] }
        let(:utc_timestamp) { Time.utc(2021, 3, 12, 18, 40, 32) }
        let(:local_tz) { TZInfo::Timezone.get('Asia/Samarkand') }
        let(:local_timestamp) { local_tz.to_local(utc_timestamp) }

        it 'converts UTC timestamps to local zone' do
          expect { system("#{cmd} >/dev/null") }
            .to change { Dir.empty?(source_dir) }.from(false).to(true)

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2021
                └── #{local_timestamp.strftime('%F_%H%M%S')}.mp4
          TREE
        end

        context 'with --keep option' do
          let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--keep'] }

          it 'copies them from source to dest' do
            expect { system("#{cmd} >/dev/null") }
              .not_to(change { `tree --noreport #{source_dir}` })

            expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
              #{dest_dir}
              └── 2021
                  └── #{local_timestamp.strftime('%F_%H%M%S')}.mp4
            TREE
          end
        end

        context 'with --dry-run option' do
          let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--dry-run'] }

          it 'is a no-op' do
            expect { system("#{cmd} >/dev/null") }
              .not_to(change { `tree --noreport #{dest_dir}` })

            expect(Dir.exist?(dest_dir)).to be(false)
          end
        end

        context 'with --library-desktop option' do
          let(:options) { ['--source', source_dir, '--library-desktop', dest_dir] }

          it 'transcodes at quality -crf 28'
        end

        context 'with --library-web option' do
          let(:options) { ['--source', source_dir, '--library-web', dest_dir] }

          it 'transcodes at quality -crf 35'
        end

        context 'with --shift-timestamp option' do
          let(:options) do
            [
              '--source', source_dir,
              '--library-master', dest_dir,
              '--shift-timestamp', '-3'
            ]
          end

          let(:adjusted_timestamp) { Time.new(2021, 3, 12, 15, 40, 32) } # actual (UTC) timestamp is filename +8h, because...
          let(:adjusted_filename_stamp) { Time.new(2021, 3, 12, 20, 40, 32) } # ...this file is geotagged for UTC+5
          let(:dest_file) { "#{dest_dir}/#{adjusted_filename_stamp.strftime('%Y/%F_%H%M%S')}.mp4" }

          it 'applies shift to filename' do
            system("#{cmd} >/dev/null")

            expect(dest_files).to include dest_file
          end

          it 'applies shift to all date tags' do
            system("#{cmd} >/dev/null")

            expect(MiniExiftool.new(dest_file).date_time_original).to eq adjusted_timestamp
            expect(MiniExiftool.new(dest_file).create_date).to eq adjusted_timestamp
            expect(MiniExiftool.new(dest_file).modify_date).to eq adjusted_timestamp
          end
        end

        context 'with --local-tz option' do
          let(:options) do
            [
              '--source', source_dir,
              '--library-master', dest_dir,
              '--local-tz', 'Europe/Mariehamn'
            ]
          end

          let(:dest_file) { "#{dest_dir}/2021/#{local_timestamp.strftime('%F_%H%M%S')}.mp4" }

          it 'keeps original tz offset for filename' do
            expect { system("#{cmd} >/dev/null") }
              .to change { Dir.empty?(source_dir) }.from(false).to(true)

            expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
              #{dest_dir}
              └── 2021
                  └── #{local_timestamp.strftime('%F_%H%M%S')}.mp4
            TREE
          end

          it 'does not clobber GPS tags' do
            gps_pre = MiniExiftool.new(source_files.first).gps_position

            system("#{cmd} >/dev/null")

            expect(MiniExiftool.new(dest_file).gps_position).to eq(gps_pre)
          end
        end
      end

      context 'but no GPS data' do
        let(:source_files) { Dir["#{data_dir}/no-gps/VID_20210312_104032.mp4"] }
        let(:utc_timestamp) { Time.utc(2021, 3, 12, 10, 40, 32) }
        let(:local_timestamp) { utc_timestamp.getlocal }

        it 'converts UTC timestamps to system-local zone' do
          expect { system("#{cmd} >/dev/null") }
            .to change { Dir.empty?(source_dir) }.from(false).to(true)

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2021
                └── #{local_timestamp.strftime('%F_%H%M%S')}.mp4
          TREE
        end

        context 'with --local-tz option' do
          let(:options) do
            [
              '--source', source_dir,
              '--library-master', dest_dir,
              '--local-tz', 'Europe/Mariehamn' 
            ]
          end

          let(:dest_file) { "#{dest_dir}/2021/2021-03-12_124032.mp4" }

          it 'applies time zone offset to filename' do
            system("#{cmd} >/dev/null")

            expect(dest_files).to include dest_file
          end

          it 'writes GPS tags' do
            system("#{cmd} >/dev/null")

            expect(MiniExiftool.new(dest_file).gps_latitude).to eq %(60 deg 5' 49.54" N)
            expect(MiniExiftool.new(dest_file).gps_longitude).to eq %(19 deg 56' 5.40" E)
          end
        end
      end
    end

    context 'for MOVs with timestamp metadata' do
      let(:source_files) { Dir["#{data_dir}/basic/*.mov"] }
      let(:utc_timestamp) { Time.utc(2020, 5, 1, 7, 20, 11) }
      let(:local_timestamp) { utc_timestamp.getlocal }

      it 'converts UTC timestamps to local zone' do
        expect { system("#{cmd} >/dev/null") }
          .to change { Dir.empty?(source_dir) }.from(false).to(true)

        expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
          #{dest_dir}
          └── 2020
              └── #{local_timestamp.strftime('%F_%H%M%S')}.mov
        TREE
      end

      context 'with --keep option' do
        let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--keep'] }

        it 'copies them from source to dest' do
          expect { system("#{cmd} >/dev/null") }
            .not_to(change { `tree --noreport #{source_dir}` })

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2020
                └── #{local_timestamp.strftime('%F_%H%M%S')}.mov
          TREE
        end
      end

      context 'with --dry-run option' do
        let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--dry-run'] }

        it 'is a no-op' do
          expect { system("#{cmd} >/dev/null") }
            .not_to(change { `tree --noreport #{dest_dir}` })

          expect(Dir.exist?(dest_dir)).to be(false)
        end
      end

      context 'with --library-desktop option' do
        let(:options) { ['--source', source_dir, '--library-desktop', dest_dir] }

        it 'transcodes at quality -crf 28'
      end

      context 'with --library-web option' do
        let(:options) { ['--source', source_dir, '--library-web', dest_dir] }

        it 'transcodes at quality -crf 35'
      end
    end

    shared_examples 'chat app downloads (with missing timestamp metadata)' do |app|
      let(:video_filename) { '2021-04-28_000007.mp4' }
      let(:photo_filename) { '2021-04-28_000008.jpg' }

      it "parses timestamps in #{app} filenames" do
        system("#{cmd} >/dev/null")

        expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
          #{dest_dir}
          └── 2021
              ├── #{video_filename}
              └── #{photo_filename}
        TREE
      end
    end

    it_behaves_like 'chat app downloads (with missing timestamp metadata)', 'LINE' do
      let(:source_files) { Dir["#{data_dir}/line/*"] }
    end

    it_behaves_like 'chat app downloads (with missing timestamp metadata)', 'WhatsApp' do
      let(:source_files) { Dir["#{data_dir}/whatsapp/*"] }
    end

    it_behaves_like 'chat app downloads (with missing timestamp metadata)', 'Signal' do
      let(:source_files) { Dir["#{data_dir}/signal/*"] }
    end

    it_behaves_like 'chat app downloads (with missing timestamp metadata)', 'Telegram' do
      let(:source_files) { Dir["#{data_dir}/telegram/*"] }
    end

    context 'for nested source files' do
      before do
        FileUtils.rm_rf(source_dir)
        FileUtils.mkdir_p("#{source_dir}/subdir")
        FileUtils.cp(source_files, "#{source_dir}/subdir")
      end

      it 'does not move them' do
        expect { system("#{cmd} >/dev/null") }
          .not_to(change { `tree --noreport #{source_dir}` })

        expect(Dir.exist?(dest_dir)).to be(false)
      end

      context 'with --recursive option' do
        let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--recursive'] }

        it 'does move them' do
          expect { system("#{cmd} >/dev/null") }
            .to change { Dir.empty?(source_dir) }.from(false).to(true)

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2020
                └── 2020-02-14_225530.jpg
          TREE
        end
      end
    end

    context 'for files in use by other processes' do
      let(:source_files) { Dir["#{data_dir}/basic/*.mp4"] }
      let!(:pid) { spawn("tail -f >> #{Dir["#{source_dir}/*"].first} 2>/dev/null &") }

      after { Process.kill(:SIGINT, pid) }

      it 'copies them anyway' do
        system("#{cmd} >/dev/null")

        expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
          #{dest_dir}
          └── 2021
              └── 2021-03-12_234032.mp4
        TREE
      end

      context 'with --safe option' do
        let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--safe'] }

        it 'skips them' do
          expect { system("#{cmd} >/dev/null 2>&1") }
            .not_to(change { `tree --noreport #{source_dir}` })

          expect(Dir.exist?(dest_dir)).to be(false)
        end
      end
    end

    context 'with corrupted video files' do
      let(:source_files) { Dir["#{data_dir}/{corrupted,basic}/*.mp4"] }

      it 'skips and continues processing' do
        system("#{cmd} >/dev/null")

        expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
          #{dest_dir}
          └── 2021
              └── 2021-03-12_234032.mp4
        TREE
      end
    end
  end
end
