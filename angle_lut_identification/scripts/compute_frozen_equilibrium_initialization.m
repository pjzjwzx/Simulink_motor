function initial = compute_frozen_equilibrium_initialization( ...
        c,cfg,fixedBias,activeEnable,runtimeLut)
%COMPUTE_FROZEN_EQUILIBRIUM_INITIALIZATION Pair-consistent plant/controller IC.
%   This simulation-only helper accounts for the frozen control-angle LUT.
%   It is never used by Scheme 4/5 learning or deployment gating.

omega=double(c.omega_m_radps);
loadTorque=double(c.load_torque_Nm);
B=cfg.motor.viscous_friction_Nm_per_radps;
p=cfg.motor.pole_pairs;
psi=cfg.motor.psi_f_Wb;
theta=(0:4095).'*2*pi/4096;
sensor=local_sensor_config(c,cfg,fixedBias);
forward=anglelut.encoder_forward_model(theta,sensor);
compensation=zeros(size(theta));
if activeEnable
    assert(numel(runtimeLut)==cfg.stage2.runtime_nodes, ...
        'anglelut:FrozenEquilibriumLutSize','Frozen LUT must have 512 nodes.');
    for k=1:numel(theta)
        compensation(k)=anglelut.periodic_lut_interp( ...
            forward.theta_m_raw_rad(k),runtimeLut);
    end
end
controlError=anglelut.wrap_to_pi(forward.theta_e_raw_rad- ...
    forward.theta_true_e_rad-compensation);
meanTorqueFactor=mean(cos(controlError));
iqController=(loadTorque+B*omega)/(1.5*p*psi*max(meanTorqueFactor,0.25));
iqController=min(max(iqController,-cfg.motor.iq_limit_A),cfg.motor.iq_limit_A);
initialError=controlError(1);
initial.omega_m_radps=omega;
initial.speed_pi_output_A=iqController+B*omega;
initial.plant_idq_A=[-iqController*sin(initialError), ...
    iqController*cos(initialError)];
initial.control_error_e_rad=initialError;
initial.mean_torque_factor=meanTorqueFactor;
initial.frozen_compensation_applied=logical(activeEnable);
end

function sensor=local_sensor_config(c,cfg,fixedBias)
sensor=struct('sensor_mode',uint8(c.sensor_mode), ...
    'error_mode',uint8(c.error_mode),'pole_pairs',cfg.motor.pole_pairs, ...
    'theta0_e_rad',double(c.theta0_e_rad),'legacy_offset_e_rad',0, ...
    'fixed_error_e_rad',double(fixedBias)*cfg.motor.pole_pairs, ...
    'periodic_bias_m_rad',double(fixedBias), ...
    'periodic_amp1_m_rad',double(c.periodic_amp1_m_rad), ...
    'periodic_phase1_rad',double(c.periodic_phase1_rad), ...
    'periodic_amp2_m_rad',double(c.periodic_amp2_m_rad), ...
    'periodic_phase2_rad',double(c.periodic_phase2_rad), ...
    'counts_per_rev',double(c.encoder_counts_per_rev), ...
    'quantization_enabled',true);
end
