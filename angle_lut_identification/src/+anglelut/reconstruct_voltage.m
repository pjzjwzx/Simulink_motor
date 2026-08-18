function out = reconstruct_voltage(duty_abc, vdc_V, theta_e_rad)
%RECONSTRUCT_VOLTAGE Reconstruct interval voltage from effective duty.
%   DUTY_ABC is the effective three-phase duty [pu], after saturation and
%   delay. VDC_V is measured DC-link voltage [V]. THETA_E_RAD is the raw
%   electrical angle used only to rotate the reconstructed alpha-beta
%   voltage. No controller voltage command or plant truth is accepted.
%
%   The phase-neutral reconstruction removes common mode:
%       vabc = Vdc * (duty_abc - mean(duty_abc)).

common_mode = (duty_abc(1) + duty_abc(2) + duty_abc(3)) / 3.0;
vabc_V = vdc_V .* [duty_abc(1) - common_mode; ...
                   duty_abc(2) - common_mode; ...
                   duty_abc(3) - common_mode];
vab_V = anglelut.clarke_abc(vabc_V);
vdq_V = anglelut.park_alphabeta(vab_V, theta_e_rad);

out.common_mode_duty = common_mode;
out.vabc_V = vabc_V;
out.vab_V = vab_V;
out.vdq_V = vdq_V;

end
