require "functional/helper"

describe "waivers" do
  include FunctionalHelper

  parallelize_me! # 10s -> 2s w/ N=15

  let(:waivers_profiles_path) { "#{profile_path}/waivers" }
  let(:run_result)            { run_inspec_process(cmd, json: true) }
  let(:controls_by_id)        { run_result; @json.dig("profiles", 0, "controls").map { |c| [c["id"], c] }.to_h }
  let(:cmd)                   { "exec #{waivers_profiles_path}/#{profile_name} --waiver-file #{waivers_profiles_path}/#{profile_name}/files/#{waiver_file}" }

  attr_accessor :out

  def inspec(commandline, prefix = nil)
    @stdout = @stderr = nil
    self.out = super
  end

  def stdout
    @stdout ||= out.stdout
      .force_encoding(Encoding::UTF_8)
  end

  def stderr
    @stderr ||= out.stderr
      .force_encoding(Encoding::UTF_8)
  end

  def assert_test_outcome(expected, control_id)
    assert_equal expected, controls_by_id.dig(control_id, "results", 0, "status")
  end

  def assert_stringy(s)
    assert_kind_of String, s
    refute_empty s
  end

  def waiver_data(control_id)
    controls_by_id.dig(control_id, "waiver_data")
  end

  def assert_waiver_annotation(control_id)
    act = waiver_data control_id

    # extract data from control_id
    expiry    = !!(control_id !~ /no_expiry/)
    in_past   = !!(control_id =~ /in_past/)
    in_future = !!(control_id =~ /in_future/)
    ran       = !!(control_id !~ /not_ran/)
    default_run = !!(control_id =~ /default_run/)
    waiver_expired_in_past = /Waiver expired/ =~ act["message"]

    # higher logic
    waived      = (!expiry && !ran) || (expiry && !ran && in_future)
    # TODO: wasn't message was originally specced as being optional?
    has_message = expiry && !ran && in_past

    assert_instance_of Hash, act

    assert_stringy        act["justification"] # TODO: optional?
    assert_equal ran,     act["run"] unless default_run
    assert_equal waived,  act["skipped_due_to_waiver"]
    assert_stringy        act["message"] if     has_message
    # We supply a message indicating that the waiver has expired in all cases
    assert_equal "",      act["message"] unless has_message || waiver_expired_in_past
  end

  def refute_waiver_annotation(control_id)
    act = waiver_data control_id
    assert_instance_of Hash, act
    assert_empty act
  end

  def assert_skip_message(yea, nay, control_id = "01_only_if")
    msg = controls_by_id.dig(control_id, "results", 0, "skip_message")
    assert_includes msg, yea
    refute_includes msg, nay
  end

  describe "a fully pre-slugged control file" do
    let(:profile_name) { "basic" }
    let(:waiver_file) { "waivers.yaml" }

    # rubocop:disable Layout/AlignHash
    {
      "01_not_waivered_passes"                          => "passed",
      "02_not_waivered_fails"                           => "failed",
      "03_waivered_no_expiry_ran_passes"                => "passed",
      "04_waivered_no_expiry_ran_fails"                 => "failed",
      "05_waivered_no_expiry_not_ran"                   => "skipped",
      "06_waivered_expiry_in_past_ran_passes"           => "passed",
      "07_waivered_expiry_in_past_ran_fails"            => "failed",
      "08_waivered_expiry_in_past_not_ran"              => "passed",
      "09_waivered_expiry_in_future_ran_passes"         => "passed",
      "10_waivered_expiry_in_future_ran_fails"          => "failed",
      "11_waivered_expiry_in_future_not_ran"            => "skipped",
      "12_waivered_expiry_in_future_z_ran_passes"       => "passed",
      "13_waivered_expiry_in_future_z_ran_fails"        => "failed",
      "14_waivered_expiry_in_future_z_not_ran"          => "skipped",
      "15_waivered_expiry_in_future_string_ran_passes"  => "passed",
      "16_waivered_expiry_in_future_string_ran_fails"   => "failed",
      "17_waivered_expiry_in_future_string_not_ran"     => "skipped",
      "18_waivered_no_expiry_default_run"               => "failed",
    }.each do |control_id, expected|
      it "has all of the expected outcomes #{control_id}" do
        assert_test_outcome expected, control_id

        if control_id !~ /not_waivered/
          assert_waiver_annotation control_id
        else
          refute_waiver_annotation control_id
        end
      end
    end
  end

  describe "a fully pre-slugged control file with csv format waiver file" do
    let(:profile_name) { "basic" }
    let(:waiver_file) { "waivers.csv" }

    # rubocop:disable Layout/AlignHash
    {
      "01_not_waivered_passes"                          => "passed",
      "02_not_waivered_fails"                           => "failed",
      "03_waivered_no_expiry_ran_passes"                => "passed",
      "04_waivered_no_expiry_ran_fails"                 => "failed",
      "05_waivered_no_expiry_not_ran"                   => "skipped",
      "06_waivered_expiry_in_past_ran_passes"           => "passed",
      "14_waivered_expiry_in_future_z_not_ran"          => "skipped",
    }.each do |control_id, expected|
      it "has all of the expected outcomes #{control_id}" do
        assert_test_outcome expected, control_id

        if control_id !~ /not_waivered/
          assert_waiver_annotation control_id
        else
          refute_waiver_annotation control_id
        end
      end
    end
  end

  describe "a fully pre-slugged control file with json format waiver file" do
    let(:profile_name) { "basic" }
    let(:waiver_file) { "waivers.json" }

    # rubocop:disable Layout/AlignHash
    {
      "01_not_waivered_passes"                          => "passed",
      "02_not_waivered_fails"                           => "failed",
      "03_waivered_no_expiry_ran_passes"                => "passed",
      "04_waivered_no_expiry_ran_fails"                 => "failed",
      "05_waivered_no_expiry_not_ran"                   => "skipped",
      "06_waivered_expiry_in_past_ran_passes"           => "passed",
      "14_waivered_expiry_in_future_z_not_ran"          => "skipped",
    }.each do |control_id, expected|
      it "has all of the expected outcomes #{control_id}" do
        assert_test_outcome expected, control_id

        if control_id !~ /not_waivered/
          assert_waiver_annotation control_id
        else
          refute_waiver_annotation control_id
        end
      end
    end
  end

  describe "with --filter-waived-controls flag" do
    it "can execute and not hit failures" do
      inspec("exec " + "#{waivers_profiles_path}/purely-broken-controls" + " --filter-waived-controls --waiver-file #{waivers_profiles_path}/purely-broken-controls/files/waivers.yml" + " --no-create-lockfile" + " --no-color")
      _(stderr).must_equal ""
      _(stdout).wont_include("Control Source Code Error")
      _(stdout).must_include "\nProfile Summary: 1 successful control, 0 control failures, 0 controls skipped\n"
      assert_exit_code 0, out
    end
  end

  describe "with --retain-waiver-data flag" do
    it "can execute and not hit failures with exact same output as normal" do
      inspec("exec " + "#{waivers_profiles_path}/purely-broken-controls" + " --filter-waived-controls --retain-waiver-data --waiver-file #{waivers_profiles_path}/purely-broken-controls/files/waivers.yml" + " --no-create-lockfile" + " --no-color")
      _(stderr).must_equal ""
      _(stdout).wont_include("Control Source Code Error")
      _(stdout).must_include "\nProfile Summary: 1 successful control, 0 control failures, 2 controls skipped\n"
      assert_exit_code 101, out
    end
  end

  describe "an input and control with the same name" do
    # This is a test for a regression articulated here:
    # https://github.com/inspec/inspec/issues/4936
    it "can execute when control namespace clashes with input" do
      inspec("exec " + "#{waivers_profiles_path}/namespace-clash" + " --no-create-lockfile" + " --no-color")

      _(stdout).wont_include("Control Source Code Error")
      _(stdout).must_include "\nProfile Summary: 1 successful control, 0 control failures, 0 controls skipped\n"
      _(stderr).must_equal ""
      assert_exit_code 0, out
    end
  end

  describe "an inherited profile" do
    let(:profile_name) { "waiver-wrapper" }
    let(:waiver_file) { "waivers.yaml" }
    it "should set the data in the child but be empty in the wrapper" do
      run_result
      child_profile = @json["profiles"].detect { |p| p["name"] == "waiver-child" }
      child_waiver_data = child_profile.dig("controls", 0, "waiver_data")
      assert_instance_of Hash, child_waiver_data
      refute_empty child_waiver_data
      expected_child_waiver_data = {
        "run" => false,
        "justification" => "I said so",
        "skipped_due_to_waiver" => true,
        "message" => "",
      }
      assert_equal expected_child_waiver_data, child_waiver_data

      wrapper_profile = @json["profiles"].detect { |p| p["name"] == "waiver-wrapper" }
      wrapper_waiver_data = wrapper_profile.dig("controls", 0, "waiver_data")
      assert_instance_of Hash, wrapper_waiver_data
      assert_empty wrapper_waiver_data
    end
  end

  # describe "a profile whose control ids require transformation"

  describe "a waiver file with invalid dates" do
    let(:profile_name) { "short" }
    let(:waiver_file) { "bad-date.yaml" }
    it "gracefully errors" do
      result = run_result
      assert_includes "ERROR",    result.stdout # the error level
      assert_includes "01_small", result.stdout # the offending control ID
      assert_includes "never",    result.stdout # The bad value
      assert_equal 1, result.exit_status
    end
  end

  describe "waivers and only_if" do
    let(:profile_name) { "only_if" }

    describe "when an only_if is used with empty waiver file" do
      let(:waiver_file) { "empty.yaml" }

      it "only warn file is empty error -> empty.yaml" do
        result = run_result
        assert_includes result.stderr, "waivers/only_if/files/empty.yaml' is empty"
        assert_includes result.stderr, "Skipping waivers"
        if windows?
          assert_equal 1, result.exit_status
        else
          assert_equal 101, result.exit_status
        end
      end
    end

    describe "when an only_if is used with waiver file which has waived control with past expiration date" do
      let(:waiver_file) { "waiver.yaml" }
      it "skips the control with a waiver message" do
        assert_skip_message "test_message_from_dsl_02_only_if", "waiver", "02_only_if_when_waiver_is_expired"
      end
    end

    describe "when both a skipping waiver and an only_if are present" do
      let(:waiver_file) { "waiver.yaml" }
      it "skips the control with a waiver message" do
        assert_skip_message "waiver", "due to only_if"
      end
    end
  end

  describe "with a waiver file that does not exist" do
    let(:profile_name) { "basic" }
    let(:waiver_file) { "no_file.yaml" }
    it "raise file does not exist standard error" do
      result = run_result
      assert_includes result.stderr, "no_file.yaml does not exist"
      assert_equal 1, result.exit_status
    end
  end

  describe "with a waiver file with wrong headers" do
    let(:profile_name) { "basic" }

    describe "using csv file" do
      let(:waiver_file) { "wrong-headers.csv" }
      it "raise errors" do
        result = run_result
        assert_includes result.stderr, "ERROR: Error reading waivers file"
        assert_includes result.stderr, "Missing required header/s [\"control_id\", \"justification\"]"
        assert_includes result.stderr, "Fix headers in file to proceed."
      end
    end

    describe "using json file" do
      let(:waiver_file) { "wrong-headers.json" }
      it "raise errors" do
        result = run_result
        assert_includes result.stderr, "ERROR: Error reading waivers file"
        assert_includes result.stderr, "ERROR: Control ID 04_waivered_no_expiry_ran_fails: missing required parameter/s [\"justification\"]"
        assert_includes result.stderr, "Fix parameters in file to proceed."
        assert_includes result.stderr, "WARN: Control ID 03_waivered_no_expiry_ran_passes: extra parameter/s [\"run_random\", \"expiration_date_random\"]"
      end
    end

    describe "using yaml file" do
      let(:waiver_file) { "wrong-headers.yaml" }
      it "raise errors" do
        result = run_result
        assert_includes result.stderr, "ERROR: Error reading waivers file"
        assert_includes result.stderr, "ERROR: Control ID 04_waivered_no_expiry_ran_fails: missing required parameter/s [\"justification\"]"
        assert_includes result.stderr, "Fix parameters in file to proceed."
        assert_includes result.stderr, "WARN: Control ID 03_waivered_no_expiry_ran_passes: extra parameter/s [\"run_random\", \"expiration_date_random\"]"
      end
    end

    describe "using unsupported extension file" do
      let(:waiver_file) { "waivers.testextension" }
      it "raise error" do
        result = run_result
        assert_includes result.stderr, "Unsupported file extension"
        assert_equal 1, result.exit_status
      end
    end
  end

  describe "with a waiver file with malformed data" do
    let(:profile_name) { "basic" }
    let(:waiver_file) { "malformed-waiver.yaml" }

    it "raise error" do
      result = run_result
      assert_includes result.stderr, "ERROR:"
      assert_includes result.stderr, "invalid YAML or contents is not a Hash"
    end
  end
end
