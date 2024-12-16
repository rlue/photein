require 'spec_helper'
require 'digest'
require 'fileutils'
require 'open3'

require 'mini_magick'

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

        expect(err.chomp).to eq("photein: no source directory given")
        expect(status.exitstatus).to eq(1)
      end
    end

    context 'with no --library-*' do
      let(:options) { ['--source', source_dir] }

      it 'fails' do
        _out, err, status = Open3.capture3(cmd)

        expect(err.chomp).to eq("photein: no destination directory given")
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
                ├── 2018-09-01_145650a.jpg
                └── 2018-09-01_145650b.jpg
          TREE
        end
      end

      context 'with --keep option' do
        let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--keep'] }

        it 'copies them from source to dest' do
          expect { system("#{cmd} >/dev/null") }
            .not_to change { `tree --noreport #{source_dir}` }

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
            .not_to change { `tree --noreport #{dest_dir}` }

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
            .not_to change { `tree --noreport #{source_dir}` }

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
      let(:source_files) { Dir["#{data_dir}/basic/*.mp4"] }
      let(:utc_timestamp) { Time.new(2021, 3, 12, 18, 40, 32, 'utc') }
      let(:local_timestamp) { utc_timestamp.getlocal }

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
            .not_to change { `tree --noreport #{source_dir}` }

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
            .not_to change { `tree --noreport #{dest_dir}` }

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

    context 'for MOVs with timestamp metadata' do
      let(:source_files) { Dir["#{data_dir}/basic/*.mov"] }
      let(:utc_timestamp) { Time.new(2020, 5, 1, 7, 20, 11, 'utc') }
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
            .not_to change { `tree --noreport #{source_dir}` }

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
            .not_to change { `tree --noreport #{dest_dir}` }

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
          .not_to change { `tree --noreport #{source_dir}` }

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
              └── 2021-03-12_104032.mp4
        TREE
      end

      context 'with --safe option' do
        let(:options) { ['--source', source_dir, '--library-master', dest_dir, '--safe'] }

        it 'skips them' do
          expect { system("#{cmd} >/dev/null 2>&1") }
            .not_to change { `tree --noreport #{source_dir}` }

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
              └── 2021-03-12_104032.mp4
        TREE
      end
    end
  end
end
