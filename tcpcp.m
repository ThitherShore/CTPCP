function [P,Q,obj,err,iter] = tcpcp(dim,g,GM,GM2,lambda,opts)

% Tensor Compressive Principal Component Pursuit Algomrith
%
% Description: to solve Tensor Compressive Principal Component Analysis 
% based on Tensor Nuclear Norm problem by ADMM
%
% min_{L,S} ||L||_*+lambda*||S||_1, s.t. P_G(L+S)=P_G(L+S),
%
% where M is the original matrix,
%       P_G is sampling based on Guassian Measurement.
%
% ---------------------------------------------
% Input:
%       X       -    d1*d2*d3 tensor
%       lambda  -    >0, parameter
%       opts    -    Structure value in Matlab. The fields are
%           opts.tol        -   termination tolerance
%           opts.max_iter   -   maximum number of iterations
%           opts.mu         -   stepsize for dual variable updating in ADMM
%           opts.max_mu     -   maximum stepsize
%           opts.rho       -   0 or 1
%
% Output:      -   rho>=1, ratio used to increase mu
%           opts.DEBUG 
%       L       -    d1*d2*d3 tensor
%       S       -    d1*d2*d3 tensor
%       obj     -    objective function value
%       err     -    residual 
%       iter    -    number of iterations

tol = 1e-8; 
max_iter = 500;
rho = 1.05;
mu = 1e-1;
max_mu = 1e10;
DEBUG = 0;
penalty = 10;

if ~exist('opts', 'var')
    opts = [];
end    
if isfield(opts, 'tol');         tol = opts.tol;              end
if isfield(opts, 'max_iter');    max_iter = opts.max_iter;    end
if isfield(opts, 'rho');         rho = opts.rho;              end
if isfield(opts, 'mu');          mu = opts.mu;                end
if isfield(opts, 'max_mu');      max_mu = opts.max_mu;        end
if isfield(opts, 'penalty');     penalty = opts.penalty;      end
if isfield(opts, 'DEBUG');       DEBUG = opts.DEBUG;          end

X = reshape(GM\g,dim);%
L = X;
S = zeros(dim);
%P = L;
%Q = S;
Z1 = zeros(dim);
Z2 = zeros(dim);
%Z1 = L;
%Z2 = S;
m = prod(dim);

iter = 0;
for iter = 1 : max_iter
    Lk = L;
    Sk = S;
    % update P
    [P,tnnP] = prox_tnn(L+Z1/mu,1/mu);
    % update Q
    Q = prox_l1(S+Z2/mu,lambda/mu);
    penalty = mu;
    % update L
    [ll,~] = cgs((penalty*GM2+mu*eye(m)),(penalty*GM'*g+mu*P(:)-Z1(:)-penalty*GM2*S(:)),1e-8,300);
    L = reshape(ll,dim);
    % update S
    [ss,~] = cgs((penalty*GM2+mu*eye(m)),(penalty*GM'*g+mu*Q(:)-Z2(:)-penalty*GM2*L(:)),1e-8,300);
    S = reshape(ss,dim);
    % dual update difference
    dZ1 = L-P;
    dZ2 = S-Q;
    chgL = max(abs(Lk(:)-L(:)));
    chgS = max(abs(Sk(:)-S(:)));
    chg = max([ chgL chgS max(abs(dZ1(:))) max(abs(dZ2(:)))]);
    if DEBUG
        if iter == 1 || mod(iter, 10) == 0
            obj = tnnP+lambda*norm(S(:),1);
            err = norm(dZ1(:))+norm(dZ2(:))+norm(GM*(L(:)+S(:))-g);
            disp(['iter ' num2str(iter) ', mu=' num2str(mu) ...
                    ', obj=' num2str(obj) ', err=' num2str(err)...
                    ', norm(Z1)=' num2str(norm(abs(Z1(:)))) ', norm(Z2)=' num2str(norm(abs(Z2(:))))...
                    ', norm(P)=' num2str(norm(abs(P(:)))) ', norm(Q)=' num2str(norm(abs(Q(:))))...
                    ', norm(L)=' num2str(norm(abs(L(:)))) ', norm(S)=' num2str(norm(abs(S(:))))]); 
        end
    end
    
    if chg < tol
        break;
    end 
    % dual update Z1
    Z1 = Z1 + mu*dZ1;
    % dual update Z2
    Z2 = Z2 + mu*dZ2;
    %X = L+S;
    mu = min(rho*mu,max_mu);    
end
obj = tnnP+lambda*norm(S(:),1);
err = norm(dZ1(:))+norm(dZ2(:));
