function tests = testStage3Scheme5
%TESTSTAGE3SCHEME5 E30-E32, isolation, triggering, and replay contracts.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.cfg=stage3_config();
end

function testE30E31AndPositiveE32Update(testCase)
cfg=testCase.TestData.cfg; cfg.stage3.initial_effective_weight_per_node=1e12;
state=anglelut.scheme5_init64(cfg,cfg.stage3.MODE_NOMINAL);
phi=(7.25)*2*pi/64; sample=local_sample(phi,0.8,0.3,210,1,1,1,true);
before=state.shadow_lut_e_rad; [after,event]=anglelut.scheme5_update64(state,sample,cfg);
M=64; u=M*phi/(2*pi); alpha=u-floor(u); j0=floor(u)+1; j1=mod(floor(u)+1,M)+1;
h=[1-alpha;alpha]; a=cfg.stage3.Ts_s*cfg.stage3.psi_f_Wb*210/cfg.stage3.Ls_H;
t=0.8; gain=cfg.stage3.mu5*a*t/(cfg.stage3.epsilon5_A2+a^2*sum(h.^2));
expected=before; expected(j0)=expected(j0)+gain*h(1); expected(j1)=expected(j1)+gain*h(2);
verifyEqual(testCase,after.shadow_lut_e_rad,expected,'AbsTol',1e-14);
verifyEqual(testCase,event.tangent_residual,t,'AbsTol',1e-14);
verifyEqual(testCase,event.radial_residual,0.3-a,'AbsTol',1e-14);
end

function testCenteredFiniteDifferenceGradient(testCase)
cfg=testCase.TestData.cfg; M=64; phi=8.37*2*pi/M;
w=deg2rad(4*sin((0:M-1).'*2*pi/M));
y=[0.62;0.47]; omega=190; a=cfg.stage3.Ts_s*cfg.stage3.psi_f_Wb*omega/cfg.stage3.Ls_H;
[delta,h]=local_interp(phi,w); t=y(1)*cos(delta)-y(2)*sin(delta);
analytic=-a*t*h;
step=1e-7; numeric=zeros(M,1);
for j=find(h).'
    wp=w; wm=w; wp(j)=wp(j)+step; wm(j)=wm(j)-step;
    numeric(j)=(local_cost(phi,wp,y,a)-local_cost(phi,wm,y,a))/(2*step);
end
relative=norm(numeric-analytic)/max(norm(analytic),eps);
verifyLessThanOrEqual(testCase,relative,cfg.gates.stage3.gradient_relative_error_max);
end

function testForwardReverseNormalizedUpdateMatches(testCase)
cfg=testCase.TestData.cfg; cfg.stage3.initial_effective_weight_per_node=1e12;
s1=anglelut.scheme5_init64(cfg,cfg.stage3.MODE_NOMINAL); s2=s1;
positive=local_sample(0.23,0.71,0.12,200,0.8,1,1,true);
negative=positive; negative.omega_e_est_radps=-positive.omega_e_est_radps;
s1=anglelut.scheme5_update64(s1,positive,cfg);
s2=anglelut.scheme5_update64(s2,negative,cfg);
relative=norm(s1.shadow_lut_e_rad-s2.shadow_lut_e_rad)/ ...
    max(norm(s1.shadow_lut_e_rad),eps);
verifyLessThanOrEqual(testCase,relative, ...
    cfg.gates.stage3.reverse_update_relative_difference_max);
end

function testExactlyTwoNodesChange(testCase)
cfg=testCase.TestData.cfg; cfg.stage3.initial_effective_weight_per_node=1e12;
state=anglelut.scheme5_init128(cfg,cfg.stage3.MODE_NOMINAL);
sample=local_sample(0.41,0.8,0.1,200,1,1,1,true);
state=anglelut.scheme5_update128(state,sample,cfg);
verifyEqual(testCase,nnz(state.shadow_lut_e_rad),2);
end

function testThreeAmplitudeModesRemainFinite(testCase)
cfg=testCase.TestData.cfg; cfg.stage3.initial_effective_weight_per_node=1e12;
for mode=[cfg.stage3.MODE_NOMINAL,cfg.stage3.MODE_MEASURED_MAGNITUDE, ...
        cfg.stage3.MODE_DIRECTION_NORMALIZED]
    state=anglelut.scheme5_init64(cfg,mode);
    [state,event]=anglelut.scheme5_update64(state, ...
        local_sample(0.7,0.3,-0.2,180,0.9,1,1,true),cfg);
    verifyTrue(testCase,all(isfinite(state.shadow_lut_e_rad)));
    verifyTrue(testCase,isfinite(event.tangent_residual));
    verifyTrue(testCase,isfinite(event.radial_residual));
end
end

function testTriggerCoverageTravelAndFusion(testCase)
cfg=testCase.TestData.cfg;
cfg.stage3.node_min_hits=uint32(1); cfg.stage3.node_min_weight=0;
cfg.stage3.initial_effective_weight_per_node=1;
cfg.stage3.initial_travel_m_rad=2*pi;
state=anglelut.scheme5_init64(cfg,cfg.stage3.MODE_NOMINAL);
event.triggered=false;
for k=1:64
    phi=(k-1)*2*pi/64;
    [state,event]=anglelut.scheme5_update64(state, ...
        local_sample(phi,0,0,200,1,phi,1e-4*k,true),cfg);
end
verifyFalse(testCase,event.triggered);
[state,event]=anglelut.scheme5_update64(state, ...
    local_sample(0,0,0,200,1,2*pi,0.1,true),cfg);
verifyTrue(testCase,event.triggered);
verifyEqual(testCase,double(state.fusion_count),1);
end

function testStateFixedSizeAndNoHistoryTruthOrPlant(testCase)
cfg=testCase.TestData.cfg;
for M=[64 128]
    state=anglelut.scheme5_init(M,cfg,cfg.stage3.MODE_NOMINAL);
    verifySize(testCase,state.shadow_lut_e_rad,[M 1]);
    verifySize(testCase,state.active_lut_e_rad,[M 1]);
    verifySize(testCase,state.node_weight,[M 1]);
    names=lower(string(fieldnames(state)));
    verifyFalse(testCase,any(contains(names,["history","truth","plant","buffer"])));
end
code=lower(fileread(fullfile(cfg.project.root,'src','+anglelut','scheme5_update.m')));
verifyFalse(testCase,contains(code,'truth')); verifyFalse(testCase,contains(code,'plant'));
end

function testSampleWhitelistRejectsTraceAndTruth(testCase)
cfg=testCase.TestData.cfg; state=anglelut.scheme5_init64(cfg,cfg.stage3.MODE_NOMINAL);
sample=local_sample(0,0,0,1,1,0,0,true); sample.truth_error_e_rad=0;
verifyError(testCase,@()anglelut.scheme5_update64(state,sample,cfg), ...
    'anglelut:Scheme5SampleSchema');
sample=rmfield(sample,'truth_error_e_rad'); sample.trace=struct();
verifyError(testCase,@()anglelut.scheme5_update64(state,sample,cfg), ...
    'anglelut:Scheme5SampleSchema');
end

function testRuntime512WrapContinuity(testCase)
lut=deg2rad(8*sin((0:63).'*2*pi/64)); runtime=anglelut.resample_periodic_lut(lut,512);
verifySize(testCase,runtime,[512 1]);
verifyLessThan(testCase,abs(anglelut.periodic_lut_interp(2*pi-1e-10,runtime)- ...
    anglelut.periodic_lut_interp(1e-10,runtime)),1e-8);
end

function testDeterministicReplayAndHistoryOutsideState(testCase)
cfg=testCase.TestData.cfg; trace=local_trace(cfg,26000);
[s1,m1,h1]=stream_scheme5_trace(trace,64,cfg,cfg.stage3.MODE_NOMINAL);
[s2,m2,h2]=stream_scheme5_trace(trace,64,cfg,cfg.stage3.MODE_NOMINAL);
verifyEqual(testCase,s1,s2); verifyEqual(testCase,m1,m2); verifyEqual(testCase,h1,h2);
verifyGreaterThan(testCase,size(h1.active_lut_e_rad,1),0);
verifyFalse(testCase,isfield(s1,'history'));
end

function testFixedWrappersPassCodeGenerationScreener(testCase)
info=coder.screener('anglelut.scheme5_update64', ...
    'anglelut.scheme5_update128');
verifyEmpty(testCase,info.Messages);
verifyEmpty(testCase,info.UnsupportedCalls);
end

function sample=local_sample(phi,yd,yq,omega,chi,travel,time,valid)
sample=struct('phi_m_rad',phi,'y_d_A',yd,'y_q_A',yq, ...
    'omega_e_est_radps',omega,'quality_weight',chi, ...
    'theta_m_unwrapped_rad',travel,'timestamp_s',time,'valid',valid);
end
function [delta,h]=local_interp(phi,w)
M=numel(w); u=M*mod(phi,2*pi)/(2*pi); j0=floor(u); alpha=u-j0;
h=zeros(M,1); h(j0+1)=1-alpha; h(mod(j0+1,M)+1)=alpha; delta=h.'*w;
end
function value=local_cost(phi,w,y,a)
delta=anglelut.periodic_lut_interp(phi,w); e=y-a*[sin(delta);cos(delta)];
value=0.5*(e.'*e);
end
function trace=local_trace(cfg,n)
theta=linspace(0,20*pi,n).'; truth=deg2rad(6*sin(theta)+3*sin(2*theta+pi/4));
a=cfg.stage3.Ts_s*cfg.stage3.psi_f_Wb*(10*cfg.motor.pole_pairs)/cfg.stage3.Ls_H;
trace=struct('time_s',(0:n-1).'*cfg.timing.T_ident_s, ...
    'theta_m_raw_rad',mod(theta,2*pi),'theta_m_unwrapped_rad',theta, ...
    'y_A',a*[sin(truth),cos(truth)], ...
    'omega_e_est_radps',10*cfg.motor.pole_pairs*ones(n,1), ...
    'quality_weight',ones(n,1),'valid',true(n,1), ...
    'evaluation_mask',true(n,1),'truth_error_e_rad',truth);
end
