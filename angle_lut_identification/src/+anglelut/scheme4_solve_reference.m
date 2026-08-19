function out = scheme4_solve_reference(state)
%SCHEME4_SOLVE_REFERENCE Full mldivide reference for E22.

[d0,d1,d2,rhs] = anglelut.scheme4_matrix_diagonals(state);
Q = local_full_matrix(d0,d1,d2);
w = Q\rhs;
residual = Q*w-rhs;
out.lut_e_rad = w;
out.normal_equation_relative_residual = norm(residual,2) / ...
    max(norm(rhs,2),eps);
out.rcond = rcond(Q);
out.matrix = Q;
out.rhs = rhs;
end

function Q = local_full_matrix(d0,d1,d2)
M = numel(d0);
Q = diag(d0);
for j = 1:M
    j1 = mod(j,M)+1;
    j2 = mod(j+1,M)+1;
    Q(j,j1) = Q(j,j1)+d1(j);
    Q(j1,j) = Q(j1,j)+d1(j);
    Q(j,j2) = Q(j,j2)+d2(j);
    Q(j2,j) = Q(j2,j)+d2(j);
end
end
