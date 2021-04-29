require 'spec_helper'
require 'digest'
require 'fileutils'
require 'open3'

require 'mini_magick'

RSpec.describe 'archivist' do
  let(:data_dir) { File.expand_path('../data', __dir__) }
  let(:tmp_dir) { File.expand_path('../tmp', __dir__) }
  let(:source_dir) { "#{tmp_dir}/source" }
  let(:dest_dir) { "#{tmp_dir}/dest" }
  let(:cmd) { %(bin/archivist #{options.join(' ')}) }
  let(:options) { ['--source', source_dir, '--dest', dest_dir] }

  after { FileUtils.rm_rf(tmp_dir) }

  describe 'CLI option validation' do
    before { FileUtils.rm_rf(tmp_dir) }

    context 'with no --source' do
      let(:options) { [] }

      it 'fails' do
        _out, err, status = Open3.capture3(cmd.split.first)

        expect(err.chomp).to eq("archivist: no source directory given")
        expect(status.exitstatus).to eq(1)
      end
    end

    context 'with no --dest' do
      let(:options) { ['--source', source_dir] }

      it 'fails' do
        _out, err, status = Open3.capture3(cmd)

        expect(err.chomp).to eq("archivist: no destination directory given")
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

    context 'when --dest dir does not exist' do
      before { FileUtils.mkdir_p(source_dir) }

      it 'fails' do
        _out, err, status = Open3.capture3(cmd)

        expect(err.chomp).to end_with("#{dest_dir}: no such directory")
        expect(status.exitstatus).to eq(1)
      end
    end

    context 'when --source dir is empty' do
      before do
        FileUtils.mkdir_p(source_dir)
        FileUtils.mkdir_p(dest_dir)
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
      FileUtils.mkdir_p(dest_dir)
      FileUtils.cp(source_files, source_dir)
    end

    let(:source_files) { Dir["#{data_dir}/basic/*.jpg"] }
    let(:dest_files) { Dir["#{dest_dir}/**/*"].select(&File.method(:file?)).sort }

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
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--keep'] }

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
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--dry-run'] }

        it 'is a no-op' do
          expect { system("#{cmd} >/dev/null") }
            .not_to change { `tree --noreport #{dest_dir}` }

          expect(Dir.empty?(dest_dir)).to be(true)
        end
      end

      context 'with --optimize-for=desktop option' do
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--optimize-for', 'desktop'] }
        let!(:source_sha256) { Digest::SHA256.hexdigest(File.binread(source_files.first)) }
        let(:dest_sha256) { Digest::SHA256.hexdigest(File.binread(dest_files.first)) }

        it 'performs a simple copy' do
          system("#{cmd} >/dev/null")
          expect(source_sha256).to eq(dest_sha256)
        end
      end

      context 'with --optimize-for=web option' do
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--optimize-for', 'web'] }
        let!(:source_resolution) { MiniMagick::Image.new(source_files.first).dimensions.reduce(&:*) }
        let(:dest_resolution) { MiniMagick::Image.new(dest_files.first).dimensions.reduce(&:*) }

        it 'reduces resolution to 2MP' do
          system("#{cmd} >/dev/null")

          expect(source_resolution).to be > (2 * 1024 * 1024)
          expect(dest_resolution).to be <= (2 * 1024 * 1024)
        end
      end
    end

    context 'for MP4s with timestamp metadata' do
      let(:source_files) { Dir["#{data_dir}/basic/*.mp4"] }

      it 'moves them from source to dest' do
        expect { system("#{cmd} >/dev/null") }
          .to change { Dir.empty?(source_dir) }.from(false).to(true)

        expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
          #{dest_dir}
          └── 2021
              └── 2021-03-12_184032.mp4
        TREE
      end

      context 'with --keep option' do
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--keep'] }

        it 'copies them from source to dest' do
          expect { system("#{cmd} >/dev/null") }
            .not_to change { `tree --noreport #{source_dir}` }

          expect(`tree --noreport #{dest_dir}`).to eq(<<~TREE)
            #{dest_dir}
            └── 2021
                └── 2021-03-12_184032.mp4
          TREE
        end
      end

      context 'with --dry-run option' do
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--dry-run'] }

        it 'is a no-op' do
          expect { system("#{cmd} >/dev/null") }
            .not_to change { `tree --noreport #{dest_dir}` }

          expect(Dir.empty?(dest_dir)).to be(true)
        end
      end

      context 'with --optimize-for=desktop option' do
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--optimize-for', 'desktop'] }

        it 'transcodes at quality -crf 28'
      end

      context 'with --optimize-for=web option' do
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--optimize-for', 'web'] }

        it 'transcodes at quality -crf 35'
      end
    end

    shared_examples 'chat app downloads (no timestamp metadata)' do |app|
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

    it_behaves_like 'chat app downloads (no timestamp metadata)', 'LINE' do
      let(:source_files) { Dir["#{data_dir}/line/*"] }
    end

    it_behaves_like 'chat app downloads (no timestamp metadata)', 'WhatsApp' do
      let(:source_files) { Dir["#{data_dir}/whatsapp/*"] }
    end

    it_behaves_like 'chat app downloads (no timestamp metadata)', 'Signal' do
      let(:source_files) { Dir["#{data_dir}/signal/*"] }
    end

    it_behaves_like 'chat app downloads (no timestamp metadata)', 'Telegram' do
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

        expect(Dir.empty?(dest_dir)).to be(true)
      end

      context 'with --recursive option' do
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--recursive'] }

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
              └── 2021-03-12_184032.mp4
        TREE
      end

      context 'with --safe option' do
        let(:options) { ['--source', source_dir, '--dest', dest_dir, '--safe'] }

        it 'skips them' do
          expect { system("#{cmd} >/dev/null 2>&1") }
            .not_to change { `tree --noreport #{source_dir}` }

          expect(Dir.empty?(dest_dir)).to be(true)
        end
      end
    end

    # NOTE: Testing this would require an ugly, ugly hack.
    #
    # Kernel#system / Open3.capture3 spawn a subprocess,
    # so we can't use those with stubs/mocks
    # (e.g., `expect(self).to receive(:system).with('mount ...')`),
    # and we can't _actually_ {,u}mount without sudo or a custom fstab.
    #
    # In theory, we could use Kernel#load instead,
    # but 1) we'd have to manually modify ARGV to make it work,
    # and 2) I'm still not sure what the expectation would look like.
    context 'with --volume option' do
      it 'mounts the given volume before copying'
      it 'unmounts the given volume after completion'
      it 'unmounts the given volume on interrupt (Ctrl+C)'
      it 'unmounts the given volume on failure (e.g., empty source dir)'
    end
  end
end
