class ArgonautProfilesSequence < SequenceBase

  title 'Argonaut Data Profiles'

  description 'The FHIR server properly follows the Argonaut Data Query Implementation Guide.'

  preconditions 'Client must be authorized.' do
    !@instance.token.nil?
  end

  # --------------------------------------------------
  # Patient Profile
  # --------------------------------------------------

  test 'Valid DSTU2 patient resource provided and is accessable via read',
          'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html',
          'A server is capable of returning a patient using GET [base]/Patient/[id].' do

    patient_read_response = @client.read(FHIR::DSTU2::Patient, @instance.patient_id)
    assert_response_ok patient_read_response
    @patient = patient_read_response.resource
    assert !@patient.nil?, 'Expected valid DSTU2 Patient resource to be present'
    assert @patient.is_a?(FHIR::DSTU2::Patient), 'Expected resource to be valid DSTU2 Patient'
  end

  test 'Patient validates against Argonaut Profile',
          'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html',
          'A server returns valid FHIR Patient resources according to the Data Access Framework (DAF) Patient Profile (http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-patient.html)' do

    profile = ValidationUtil.guess_profile(@patient)
    errors = profile.validate_resource(@patient)
    assert errors.empty?, "Patient did not validate against profile: #{errors.join(", ")}"
  end

  test 'Patient has address',
          '',
          'Additional Patient resource requirement' do

    assert !@patient.nil?, 'Expected valid DSTU2 Patient resource to be present'
    assert @patient.is_a?(FHIR::DSTU2::Patient), 'Expected resource to be valid DSTU2 Patient'
    address = @patient.try(:address).try(:first)
    assert !address.nil?, 'Patient address not returned'
  end

  test 'Patient has telecom',
          '',
          'Additional Patient resource requirement' do

    assert !@patient.nil?, 'Expected valid DSTU2 Patient resource to be present'
    assert @patient.is_a?(FHIR::DSTU2::Patient), 'Expected resource to be valid DSTU2 Patient'
    telecom = @patient.try(:telecom).try(:first)
    assert !telecom.nil?, 'Patient telecom not returned'
  end

  test 'Patient supports $everything operation', '', 'DISCUSSION REQUIRED', :optional do
    everything_response = @client.fetch_patient_record(@instance.patient_id)
    skip_unless [200, 201].include?(everything_response.code)
    @everything = everything_response.resource
    assert !@everything.nil?, 'Expected valid DSTU2 Bundle resource on $everything request'
    assert @everything.is_a?(FHIR::DSTU2::Bundle), 'Expected resource to be valid DSTU2 Bundle'
  end

  test 'Resources in the Patient $everything results conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/profiles.html', 'DISCUSSION REQUIRED', :optional do

    skip_unless !@everything.nil?, 'Expected valid DSTU2 Bundle to be present as a result of $everything request'
    assert @everything.is_a?(FHIR::DSTU2::Bundle), 'Expected resource to be valid DSTU2 Bundle'

    all_errors = []
    @everything.entry.each do |entry|
      p = ValidationUtil.guess_profile(entry.resource)
      if p
        errors = p.validate_resource(entry.resource)
        all_errors.concat(errors)
      else
        errors = entry.resource.validate
        all_errors.concat(errors.values)
      end
    end
    assert(all_errors.empty?, all_errors.join("<br/>\n"))
  end

  attr_accessor :profiles_encountered
  attr_accessor :profiles_failed

  def test_resources_against_profile(resourceType, specified_profile=nil)
    @profiles_encountered = [] unless @profiles_encountered
    @profiles_failed = {} unless @profiles_failed
    options = {
      :search => {
        :flag => false,
        :compartment => nil,
        :parameters => { patient: @instance.patient_id }
      }
    }
    search_reply = @client.search("FHIR::DSTU2::#{resourceType}".constantize, options)
    assert_response_ok search_reply
    bundle = search_reply.resource
    assert !bundle.nil?, "Expected valid DSTU2 Bundle to be present as a result of #{resourceType} search request"
    assert bundle.is_a?(FHIR::DSTU2::Bundle), 'Expected resource to be valid DSTU2 Bundle'
    skip("Skip profile validation since no #{resourceType} resources found for Patient.") if bundle.entry.empty?

    all_errors = []
    bundle.entry.each do |entry|
      p = ValidationUtil.guess_profile(entry.resource)
      if specified_profile
        next unless p.url == specified_profile
      end
      if p
        @profiles_encountered << p.url
        @profiles_encountered.uniq!
        errors = p.validate_resource(entry.resource)
        unless errors.empty?
          @profiles_failed[p.url] = [] unless @profiles_failed[p.url]
          @profiles_failed[p.url].concat(errors)
        end
        all_errors.concat(errors)
      else
        errors = entry.resource.validate
        all_errors.concat(errors.values)
      end
    end
    # TODO
    # bundle = client.next_bundle
    assert(all_errors.empty?, all_errors.join("<br/>\n"))
  end

  test 'AllergyIntolerance resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-allergyintolerance.html',
          'AllergyIntolerance resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('AllergyIntolerance')
  end

  test 'CarePlan resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-careplan.html',
         'Declare a Conformance identifying the list of profiles, operations, search parameter supported.' do
    test_resources_against_profile('CarePlan', ValidationUtil::CARE_PLAN_URL)
    skip_unless @profiles_encountered.include?(ValidationUtil::CARE_PLAN_URL), 'No CarePlans found.'
    assert !@profiles_failed.include?(ValidationUtil::CARE_PLAN_URL), "CarePlans failed validation.<br/>#{@profiles_failed[ValidationUtil::CARE_PLAN_URL]}"
  end

  test 'CareTeam resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-careteam.html',
         'Declare a Conformance identifying the list of profiles, operations, search parameter supported.' do
    test_resources_against_profile('CarePlan', ValidationUtil::CARE_TEAM_URL)
    skip_unless @profiles_encountered.include?(ValidationUtil::CARE_TEAM_URL), 'No CareTeams found.'
    assert !@profiles_failed.include?(ValidationUtil::CARE_TEAM_URL), "CareTeams failed validation.<br/>#{@profiles_failed[ValidationUtil::CARE_TEAM_URL]}"
  end

  test 'Condition resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-condition.html',
         'Condition resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('Condition')
  end

  test 'Device resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-device.html',
          'Device resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('Device')
  end

  test 'DiagnosticReport resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-diagnosticreport.html',
         'DiagnosticReport resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('DiagnosticReport')
  end

  test 'DocumentReference resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-documentreference.html',
          'DocumentReference resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('DocumentReference')
  end

  test 'Goal resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-goal.html',
          'Goal resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('Goal')
  end

  test 'Immunization resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-immunization.html',
          'Immunization resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('Immunization')
  end

  test 'Medication resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medication.html',
          'Medication resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('Medication')
  end

  test 'MedicationOrder resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medicationorder.html',
          'MedicationOrder resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('MedicationOrder')
  end

  test 'MedicationStatement resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medicationstatement.html',
          'MedicationStatement resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('MedicationStatement')
  end

  test 'Observation Result resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-observationresults.html',
          'Observation Result resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('Observation', ValidationUtil::OBSERVATION_RESULTS_URL)
    skip_unless @profiles_encountered.include?(ValidationUtil::OBSERVATION_RESULTS_URL), 'No Observation Results found.'
    assert !@profiles_failed.include?(ValidationUtil::OBSERVATION_RESULTS_URL), "Observation Results failed validation.<br/>#{@profiles_failed[ValidationUtil::OBSERVATION_RESULTS_URL]}"
  end

  test 'Procedure resources associated with Procedure conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-procedure.html',
          'Procedure resources associated with Procedure conform to Argonaut profiles' do
    test_resources_against_profile('Procedure')
  end

  test 'Smoking Status resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-smokingstatus.html',
          'Procedure resources associated with Procedure conform to Argonaut profiles' do
    test_resources_against_profile('Observation', ValidationUtil::SMOKING_STATUS_URL)
    skip_unless @profiles_encountered.include?(ValidationUtil::SMOKING_STATUS_URL), 'No Smoking Status Observations found.'
    assert !@profiles_failed.include?(ValidationUtil::SMOKING_STATUS_URL), "Smoking Status Observations failed validation.<br/>#{@profiles_failed[ValidationUtil::SMOKING_STATUS_URL]}"
  end

  test 'Vital Signs resources associated with Patient conform to Argonaut profiles',
          'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-vitalsigns.html',
          'Vital Signs resources associated with Patient conform to Argonaut profiles' do
    test_resources_against_profile('Observation', ValidationUtil::VITAL_SIGNS_URL)
    skip_unless @profiles_encountered.include?(ValidationUtil::VITAL_SIGNS_URL), 'No Vital Sign Observations found.'
    assert !@profiles_failed.include?(ValidationUtil::VITAL_SIGNS_URL), "Vital Sign Observations failed validation.<br/>#{@profiles_failed[ValidationUtil::VITAL_SIGNS_URL]}"
  end
end
