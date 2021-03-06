# encoding: UTF-8
require 'metadata/processors'
require 'tempfile'

class TestProcessor < Minitest::Test
  def test_creates_instance_of_shellrunner
    shell_runner = Minitest::Mock.new
    shell_runner.expect :new, self
    Metadata.stub_const(:ShellRunner, shell_runner) do
      Metadata::Processor.new
    end
    shell_runner.verify
  end
end

class TestYAMLFrontmatterProcessor < Minitest::Test
  def setup
    @metadata = {'title' => 'My great note', 'tags' => 'foo'}
    @content  = 'My Markdown content'
    @file     = Tempfile.new('YAMLFM')
    @yamlfm   = Metadata::YAMLFrontmatterProcessor.new
  end

  def teardown
    @file.close!
  end

  def test_reads_and_strips_frontmatter_if_found
    document = ['---', *@metadata.map {|k,v| "#{k}: #{v}" }, '---', @content].join($/) << $/
    @file.write(document)
    @file.rewind
    assert_equal [@metadata, @content], @yamlfm.call(@file)
  end

  def test_leaves_file_alone_if_no_frontmatter_found
    document = [@content, 'Some *nice* stuff here.'].join($/) << $/
    @file.write(document)
    @file.rewind
    assert_equal([{}, nil], @yamlfm.call(@file))
    assert_equal document, File.read(@file.path)
  end

  def test_returns_empty_if_file_invalid
    @file.close!
    assert_equal([{}, nil], @yamlfm.call(@file))
  end
end

class TestLegacyFrontmatterProcessor < Minitest::Test
  def setup
    @metadata = {'=' => 'My notebook', '@' => 'foo'}
    @content  = 'My Markdown content'
    @file     = Tempfile.new('LegacyFM')
    @legacyfm = Metadata::LegacyFrontmatterProcessor.new
  end

  def teardown
    @file.close!
  end

  def test_converts_frontmatter_to_mmd_metadata_if_found
    document  = [*@metadata.map {|k,v| "#{k} #{v}" }, '', @content].join($/)
    converted = document.gsub(/^= /, 'Notebook: ').gsub(/^\@ /, 'Tags: ')
    @file.write(document)
    @file.rewind
    assert_equal([{}, converted], @legacyfm.call(@file))
  end

  def test_leaves_file_alone_if_no_frontmatter_found
    document = [@content, 'Some *nice* stuff here.'].join($/)
    @file.write(document)
    @file.rewind
    assert_equal([{}, document], @legacyfm.call(@file))
  end

  def test_raises_runtime_error_on_sed_error
    @file.close!
    e = assert_raises(RuntimeError) { assert_output('', /^.+ sed .+$/) { @legacyfm.call(@file) } }
    assert_match /`sed` exited with status [1-9][0-9]*/, e.to_s
  end
end

class TestAggregatingProcessor < Minitest::Test
  def setup
    @values = {scalar: 'Foo', set: [1, 2]}
  end

  def new_processor(**keys)
    # We must `eval` to get @values as the block is `instance_exec`’d in the Processor’s context.
    eval "Metadata::AggregatingProcessor.new(**keys) { |file, key| #{@values}[key] }"
  end

  def test_exposes_keys_reader
    processor = new_processor(@values)
    assert_respond_to processor, :keys
    refute_respond_to processor, :keys=
    assert_equal @values, processor.keys
  end

  def test_retrieves_a_hash_of_values_indexed_on_keys
    keys      = {string: :scalar, array: :set}
    processor = new_processor(**keys)
    values    = processor.call(__FILE__)
    assert_instance_of Hash, values
    assert_equal keys.keys,  values.keys
  end

  def test_retrieves_and_merges_scalar_data_points
    processor = new_processor(string: [:scalar, :scalar])
    values    = processor.call(__FILE__)
    assert_equal @values[:scalar], values[:string]
  end

  def test_retrieves_and_merges_array_data_points
    processor = new_processor(array: [:set, :set])
    values    = processor.call(__FILE__)
    assert_equal @values[:set], values[:array]
  end

  def test_retrieves_and_merges_mixed_data_points
    processor = new_processor(mix: [:scalar, :set])
    values    = processor.call(__FILE__)
    assert_equal @values.values.flatten, values[:mix]
  end

  def test_raises_argument_error_if_keys_or_block_missing
    assert_raises(ArgumentError) { new_processor }
    assert_raises(ArgumentError) { Metadata::AggregatingProcessor.new(@values) }
  end

end

class TestSpotlightPropertiesProcessor < Minitest::Test
  def setup
    @file  = File.new(__FILE__)
  end

  def teardown
    @file.close
  end

  def new_processor(**keys)
    Metadata::SpotlightPropertiesProcessor.new(**keys)
  end

  def test_retrieves_and_merges_scalar_data_points
    values = new_processor(name: 'kMDItemFSName').call(@file)
    assert_instance_of String, values[:name]
    assert_equal File.basename(@file.path), values[:name]

    values = new_processor(type: ['kMDItemContentType', 'kMDItemKind']).call(@file)
    assert_instance_of Array, values[:type]
    assert_equal values[:type].compact.uniq.count, values[:type].count
  end

  def test_retrieves_and_merges_array_data_points
    single = new_processor(tree: 'kMDItemContentTypeTree').call(@file)
    assert_instance_of Array, single[:tree]
    assert_equal single[:tree].compact.uniq.count, single[:tree].count

    double = new_processor(tree: ['kMDItemContentTypeTree', 'kMDItemContentTypeTree']).call(@file)
    assert_instance_of Array, double[:tree]
    assert_equal single, double
  end
end

class FilePropertiesProcessor < Minitest::Test
  def setup
    @file  = File.new(__FILE__)
  end

  def teardown
    @file.close
  end

  def test_retrieves_file_method_properties
    keys = {atime: :atime, path: :path}
    values = Metadata::FilePropertiesProcessor.new(**keys).call(@file)
    assert_equal keys.count, values.count
    assert_instance_of Time, values[:atime]
    assert_instance_of String, values[:path]
  end
end
