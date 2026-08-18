function map = signal_map()
%SIGNAL_MAP Stage 0 signal provenance and Stage 1 interface mapping.
%   Paths refer to the preserved baseline model.  The harness may branch
%   these signals, but deployment calculations must use only entries under
%   identification; truth entries are evaluation-only.

model = "FOC_fw_hifi_v1_0709backup";
busSelector = model + "/Bus" + newline + "Selector1";

map.schema_version = "stage1-signal-map-v1";
map.baseline_model = model;
map.harness_model = "angle_lut_harness";

map.identification.iabc_A.source_blocks = [ ...
    model + "/Current_Sensing_ADC_Latency_Ia"; ...
    model + "/Current_Sensing_ADC_Latency_Ib"; ...
    model + "/Current_Sensing_ADC_Latency_Ic"];
map.identification.iabc_A.source_ports = [1; 1; 1];
map.identification.iabc_A.units = "A";
map.identification.duty_abc.source_block = model + "/PWM_and_Actuation";
map.identification.duty_abc.source_port = 1;
map.identification.duty_abc.semantics = "saturated duty effective at inverter input";
map.identification.vdc_V.source_block = model + "/Constant8";
map.identification.vdc_V.source_port = 1;
map.identification.vdc_V.units = "V";
map.identification.theta_m_raw_rad.source_block = ...
    model + "/Position_Sensing_Encoder_Latency_Theta";
map.identification.theta_m_raw_rad.source_port = 1;
map.identification.theta_m_raw_rad.units = "mechanical rad";
map.identification.omega_e_radps.source = ...
    "anglelut.estimate_speed_step(theta_m_unwrapped,timestamp), multiplied by pole pairs";
map.identification.validity.source = "harness validity and saturation logic";
map.identification.timestamp.source = "harness discrete event timestamps";

map.operating_point.speed_step.variable = "stage1_speed_target_rpm";
map.operating_point.speed_step.actual_units = "mechanical rev/s";
map.operating_point.speed_step.conversion = "omega_m_radps/(2*pi)";
map.operating_point.speed_step.note = ...
    "The inherited block label says RPM, but its immediate gain is 2*pi, not 2*pi/60.";

map.truth.theta_m_true_rad.source_block = busSelector;
map.truth.theta_m_true_rad.source_port = 6;
map.truth.theta_m_true_rad.signal_name = "<MtrPos>";
map.truth.theta_e_true_rad.source_block = busSelector;
map.truth.theta_e_true_rad.source_port = 11;
map.truth.theta_e_true_rad.signal_name = "<MtrElcPos>";
map.truth.omega_m_true_radps.source_block = busSelector;
map.truth.omega_m_true_radps.source_port = 1;
map.truth.omega_m_true_radps.signal_name = "<MtrSpd>";
map.truth.injected_error.source = "mechanical Stage 1 encoder forward model";
map.truth.plant_vabc_V.source_block = model + "/Inverter_Nonideal";
map.truth.plant_vabc_V.source_port = 1;
map.truth.plant_vabc_V.semantics = "voltage actually connected to PMSM plant";

map.forbidden_identification_sources = [ ...
    "EvaluationTruthBus"; "theta_m_true_rad"; "theta_e_true_rad"; ...
    "omega_m_true_radps"; "omega_e_true_radps"; ...
    "injected_error_m_rad"; "injected_error_e_rad"; ...
    "plant_vabc_V"; "plant_vdq_V"];
map.truth_use_policy = ...
    "EvaluationTruthBus is permitted only in evaluation, metrics, and plotting.";
map.raw_source_buses.identification = "RawIdentificationSourceBus";
map.raw_source_buses.truth = "RawEvaluationTruthSourceBus";
map.raw_source_buses.policy = ...
    "The copied model exposes incomplete raw observer feeds under Raw* names. " + ...
    "The analysis layer must assemble the complete formal IdentificationBus " + ...
    "before residual evaluation and the complete EvaluationTruthBus only after it.";
end
