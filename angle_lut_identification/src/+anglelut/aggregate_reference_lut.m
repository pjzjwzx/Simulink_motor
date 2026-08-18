function ref = aggregate_reference_lut(phi_rad, delta_e_rad, M, valid)
%AGGREGATE_REFERENCE_LUT Build evaluation truth on the raw-angle index.
%   This evaluation-only utility aggregates sample pairs (PHI, DELTA) using
%   E09's two periodic interpolation weights. PHI is raw mechanical angle
%   [rad_m]; DELTA is circular electrical error [rad_e]. Truth enters only
%   this reference utility, never PHYSICAL_RESIDUAL or QUALITY_GATES.
%
%   Empty nodes are NaN and marked false in VALID_MASK. The circular mean
%   avoids a discontinuity if error samples straddle the +/-pi branch.

sum_sin = zeros(M, 1);
sum_cos = zeros(M, 1);
weight_sum = zeros(M, 1);
sample_hits = zeros(M, 1, 'uint32');
accepted_samples = uint32(0);

N = min(numel(phi_rad), min(numel(delta_e_rad), numel(valid)));
for k = 1:N
    if valid(k) && isfinite(phi_rad(k)) && isfinite(delta_e_rad(k))
        phi_k = anglelut.wrap_to_2pi(phi_rad(k));
        delta_k = anglelut.wrap_to_pi(delta_e_rad(k));
        u = M * phi_k / (2.0 * pi);
        j0_zero_based = floor(u);
        alpha = u - j0_zero_based;
        j0 = j0_zero_based + 1;
        j1 = mod(j0_zero_based + 1, M) + 1;
        w0 = 1.0 - alpha;
        w1 = alpha;

        if w0 > 0.0
            sum_sin(j0) = sum_sin(j0) + w0 * sin(delta_k);
            sum_cos(j0) = sum_cos(j0) + w0 * cos(delta_k);
            weight_sum(j0) = weight_sum(j0) + w0;
            sample_hits(j0) = sample_hits(j0) + uint32(1);
        end
        if w1 > 0.0
            sum_sin(j1) = sum_sin(j1) + w1 * sin(delta_k);
            sum_cos(j1) = sum_cos(j1) + w1 * cos(delta_k);
            weight_sum(j1) = weight_sum(j1) + w1;
            sample_hits(j1) = sample_hits(j1) + uint32(1);
        end
        accepted_samples = accepted_samples + uint32(1);
    end
end

lut_e_rad = NaN(M, 1);
valid_mask = (weight_sum > 0.0);
for j = 1:M
    if valid_mask(j)
        lut_e_rad(j) = atan2(sum_sin(j), sum_cos(j));
    end
end

ref.node_phi_m_rad = (0:(M - 1)).' * (2.0 * pi / M);
ref.lut_e_rad = lut_e_rad;
ref.valid_mask = valid_mask;
ref.weight_sum = weight_sum;
ref.sample_hits = sample_hits;
ref.accepted_samples = accepted_samples;
ref.coverage_fraction = sum(double(valid_mask)) / M;

end
