function out = scheme4_solve_banded(state)
%SCHEME4_SOLVE_BANDED Fixed cyclic-pentadiagonal E22 solver.
%   The four wrap-boundary nodes form a small Schur complement.  The
%   remaining interior is solved with an O(M) bandwidth-two Cholesky
%   factorization.  No pseudoinverse or dynamic history is used.

[d0,d1,d2,rhs] = anglelut.scheme4_matrix_diagonals(state);
M = numel(d0);
assert(M >= 8,'anglelut:Scheme4TooFewNodes', ...
    'The bordered band solver requires at least eight nodes.');

boundary = [1,2,M-1,M];
interior = (3:(M-2)).';
n = numel(interior);
a0 = d0(interior);
a1 = d1(interior(1:end-1));
a2 = d2(interior(1:end-2));
[ld,l1,l2] = local_band_cholesky(a0,a1,a2);

Qib = zeros(n,4);
Qbb = zeros(4,4);
for r = 1:n
    for c = 1:4
        Qib(r,c) = local_entry(interior(r),boundary(c),d0,d1,d2);
    end
end
for r = 1:4
    for c = 1:4
        Qbb(r,c) = local_entry(boundary(r),boundary(c),d0,d1,d2);
    end
end

y = local_band_solve(ld,l1,l2,rhs(interior));
Y = zeros(n,4);
for c = 1:4
    Y(:,c) = local_band_solve(ld,l1,l2,Qib(:,c));
end
schur = Qbb-Qib.'*Y;
rhsBoundary = rhs(boundary)-Qib.'*y;
xBoundary = local_dense_cholesky_solve(schur,rhsBoundary);
xInterior = y-Y*xBoundary;

w = zeros(M,1);
w(interior) = xInterior;
w(boundary) = xBoundary;
residual = local_multiply(d0,d1,d2,w)-rhs;
out.lut_e_rad = w;
out.normal_equation_relative_residual = norm(residual,2) / ...
    max(norm(rhs,2),eps);
out.boundary_schur_rcond = rcond(schur);
end

function [ld,l1,l2] = local_band_cholesky(a0,a1,a2)
n = numel(a0);
ld = zeros(n,1);
l1 = zeros(n,1);
l2 = zeros(n,1);
for i = 1:n
    pivot = a0(i)-l1(i)^2-l2(i)^2;
    assert(isfinite(pivot) && pivot > 0, ...
        'anglelut:Scheme4MatrixNotSPD', ...
        'The E22 interior matrix is not positive definite.');
    ld(i) = sqrt(pivot);
    if i+2 <= n
        l2(i+2) = a2(i)/ld(i);
    end
    if i+1 <= n
        correction = l2(i+1)*l1(i);
        l1(i+1) = (a1(i)-correction)/ld(i);
    end
end
end

function x = local_band_solve(ld,l1,l2,b)
n = numel(ld);
y = zeros(n,1);
for i = 1:n
    v = b(i);
    if i > 1, v = v-l1(i)*y(i-1); end
    if i > 2, v = v-l2(i)*y(i-2); end
    y(i) = v/ld(i);
end
x = zeros(n,1);
for i = n:-1:1
    v = y(i);
    if i < n, v = v-l1(i+1)*x(i+1); end
    if i+2 <= n, v = v-l2(i+2)*x(i+2); end
    x(i) = v/ld(i);
end
end

function x = local_dense_cholesky_solve(A,b)
n = numel(b);
L = zeros(n,n);
for i = 1:n
    for j = 1:i
        v = A(i,j);
        for k = 1:(j-1)
            v = v-L(i,k)*L(j,k);
        end
        if i == j
            assert(isfinite(v) && v > 0, ...
                'anglelut:Scheme4SchurNotSPD', ...
                'The E22 boundary Schur complement is not positive definite.');
            L(i,j) = sqrt(v);
        else
            L(i,j) = v/L(j,j);
        end
    end
end
y = zeros(n,1);
for i = 1:n
    y(i) = (b(i)-L(i,1:i-1)*y(1:i-1))/L(i,i);
end
x = zeros(n,1);
for i = n:-1:1
    x(i) = (y(i)-L(i+1:n,i).'*x(i+1:n))/L(i,i);
end
end

function value = local_entry(i,j,d0,d1,d2)
M = numel(d0);
if i == j
    value = d0(i);
elseif j == mod(i,M)+1
    value = d1(i);
elseif i == mod(j,M)+1
    value = d1(j);
elseif j == mod(i+1,M)+1
    value = d2(i);
elseif i == mod(j+1,M)+1
    value = d2(j);
else
    value = 0.0;
end
end

function y = local_multiply(d0,d1,d2,x)
M = numel(x);
y = d0.*x;
for j = 1:M
    j1 = mod(j,M)+1;
    j2 = mod(j+1,M)+1;
    y(j) = y(j)+d1(j)*x(j1)+d2(j)*x(j2);
    y(j1) = y(j1)+d1(j)*x(j);
    y(j2) = y(j2)+d2(j)*x(j);
end
end
