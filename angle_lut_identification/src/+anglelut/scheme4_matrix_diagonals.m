function [d0,d1,d2,rhs] = scheme4_matrix_diagonals(state)
%SCHEME4_MATRIX_DIAGONALS Normalized E22 cyclic pentadiagonal system.

assert(state.S > 0 && isfinite(state.S), ...
    'anglelut:Scheme4ZeroWeight','Cannot solve Scheme 4 with S<=0.');
d0 = state.diag_A/state.S + (6*state.lambda_s + state.lambda0);
d1 = state.neighbor_A/state.S - 4*state.lambda_s;
d2 = state.lambda_s*ones(double(state.M),1);
rhs = state.b/state.S + state.lambda0*state.shadow_lut_e_rad;
end
