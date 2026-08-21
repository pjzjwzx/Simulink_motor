function manifest = generate_stage4_reports(diagnosticResult, trainingHistories, ...
        sweeps, frozenMatrix, schemeComparisons, outputDir)
%GENERATE_STAGE4_REPORTS Build the auditable Scheme-2 diagnostic bundle.
%   This reporting-only function accepts in-memory Stage-4 diagnostic data.
%   Missing or partial inputs produce explicit placeholder artifacts rather
%   than preventing a BLOCKED/partial run from being archived.

arguments
    diagnosticResult (1,1) struct
    trainingHistories
    sweeps
    frozenMatrix
    schemeComparisons
    outputDir (1,:) char
end

if ~isfolder(outputDir), mkdir(outputDir); end
histories = local_normalize_histories(trainingHistories);
learning = local_learning_table(histories);
rmse = local_rmse_table(histories);
[noiseComparison,noiseReason] = local_noise_comparison(histories);
[noiseFloor,noiseFloorReason] = local_noise_floor(noiseComparison);
sweepTable = local_normalize_sweeps(sweeps);
frozenTable = local_normalize_frozen(frozenMatrix);
comparisonTable = local_normalize_comparisons(schemeComparisons);

spec = [ ...
    struct('name','learning_lut_evolution', ...
        'title','Scheme 2 LUT learning evolution'), ...
    struct('name','rmse_vs_fusion_time_cycles', ...
        'title','LUT RMSE versus fusion, time, and travel'), ...
    struct('name','noisy_vs_zero_lut', ...
        'title','Final LUT: noisy versus zero-noise training'), ...
    struct('name','frozen_2x2_matrix', ...
        'title','Frozen training/evaluation 2x2 matrix'), ...
    struct('name','per_node_noise_floor', ...
        'title','Per-node LUT noise floor'), ...
    struct('name','ofat_sweeps', ...
        'title','One-factor-at-a-time sweeps'), ...
    struct('name','scheme4_5_2_cost_comparison', ...
        'title','Scheme 4 / 5 / 2 accuracy and cost comparison')];
reports = repmat(local_empty_entry(),numel(spec),1);

for k = 1:numel(spec)
    fig = local_figure();
    switch spec(k).name
        case 'learning_lut_evolution'
            [available,reason] = local_draw_learning(fig,histories,spec(k).title);
            data = learning;
        case 'rmse_vs_fusion_time_cycles'
            [available,reason] = local_draw_rmse(fig,rmse,spec(k).title);
            data = rmse;
        case 'noisy_vs_zero_lut'
            [available,reason] = local_draw_noise_comparison(fig, ...
                noiseComparison,spec(k).title,noiseReason);
            data = noiseComparison;
        case 'frozen_2x2_matrix'
            [available,reason] = local_draw_frozen(fig,frozenTable,spec(k).title);
            data = frozenTable;
        case 'per_node_noise_floor'
            [available,reason] = local_draw_noise_floor(fig,noiseFloor, ...
                spec(k).title,noiseFloorReason);
            data = noiseFloor;
        case 'ofat_sweeps'
            [available,reason] = local_draw_sweeps(fig,sweepTable,spec(k).title);
            data = sweepTable;
        otherwise
            [available,reason] = local_draw_comparison(fig,comparisonTable, ...
                spec(k).title);
            data = comparisonTable;
    end
    if ~available, local_placeholder(fig,spec(k).title,reason); end
    reports(k) = local_export_report(fig,outputDir,spec(k).name, ...
        available,reason,data);
    if strcmp(spec(k).name,'learning_lut_evolution')
        gifPath = fullfile(outputDir,'learning_lut_evolution.gif');
        local_write_learning_gif(histories,fig,gifPath);
        reports(k).gif = gifPath;
        reports(k).gif_bytes = local_file_bytes(gifPath);
    end
    close(fig);
end

manifest = struct( ...
    'schema_version','angle-lut-stage4-report-bundle-v1', ...
    'generated_at_utc',local_iso_time(), ...
    'run_id',local_text_field(diagnosticResult,{'run_id'},''), ...
    'final_status',local_text_field(diagnosticResult, ...
        {'final_status','status'},'UNKNOWN'), ...
    'diagnostic_outcome',local_diagnostic_outcome(diagnosticResult), ...
    'reporting_only',true, ...
    'partial_and_blocked_safe',true, ...
    'evaluation_truth_used_for_scoring_only',true, ...
    'truth_feedback_used',false, ...
    'history_count',numel(histories), ...
    'sweep_row_count',height(sweepTable), ...
    'frozen_pair_count',height(frozenTable), ...
    'scheme_comparison_row_count',height(comparisonTable), ...
    'reports',reports);
write_json_file(fullfile(outputDir,'report_manifest.json'),manifest);
end

function histories = local_normalize_histories(inputValue)
if isempty(inputValue)
    histories = repmat(local_empty_history(),0,1);
    return;
end
if iscell(inputValue), inputValue = [inputValue{:}]; end
assert(isstruct(inputValue),'anglelut:Stage4ReportHistories', ...
    'trainingHistories must be a struct array or cell array of structs.');
histories = repmat(local_empty_history(),numel(inputValue),1);
for k = 1:numel(inputValue)
    histories(k) = local_normalize_history(inputValue(k),k);
end
end

function out = local_normalize_history(value,index)
out = local_empty_history();
out.condition = string(local_text_field(value, ...
    {'condition','case_id','profile_id','training_condition'}, ...
    sprintf('history_%02d',index)));
out.active_lut_e_rad = local_numeric_field(value, ...
    {'active_lut_e_rad','active_lut','active_history_e_rad'},[]);
out.shadow_lut_e_rad = local_numeric_field(value, ...
    {'shadow_lut_e_rad','shadow_lut','shadow_history_e_rad'},[]);
out.reference_lut_e_rad = local_numeric_field(value, ...
    {'reference_lut_e_rad','reference_e_rad','truth_lut_e_rad'},[]);
out.reference_lut_e_rad = double(out.reference_lut_e_rad(:));

if isempty(out.active_lut_e_rad)
    out.reason = 'Active-LUT fusion history is missing.';
    return;
end
active = double(out.active_lut_e_rad);
if isvector(active), active = active(:).'; end
M = numel(out.reference_lut_e_rad);
if M > 0 && size(active,2) ~= M && size(active,1) == M
    active = active.';
end
if M == 0, M = size(active,2); end
if size(active,2) ~= M
    out.reason = 'Active-LUT history and reference node counts disagree.';
    return;
end
out.active_lut_e_rad = active;
F = size(active,1);

shadow = double(out.shadow_lut_e_rad);
if isempty(shadow)
    shadow = nan(F,M);
elseif isvector(shadow)
    shadow = shadow(:).';
end
if size(shadow,2) ~= M && size(shadow,1) == M, shadow = shadow.'; end
if size(shadow,1) == 1 && F > 1, shadow = repmat(shadow,F,1); end
if ~isequal(size(shadow),[F M]), shadow = nan(F,M); end
out.shadow_lut_e_rad = shadow;

out.fusion_count = local_vector_field(value, ...
    {'fusion_count','fusion_event','solve_count'},(1:F).',F);
out.time_s = local_vector_field(value, ...
    {'time_s','fusion_time_s','timestamp_s'},nan(F,1),F);
travel = local_numeric_field(value,{'travel_m_rad','fusion_travel_m_rad'},[]);
cycles = local_numeric_field(value,{'mechanical_cycles','cycles'},[]);
if ~isempty(travel)
    out.mechanical_cycles = local_fit_vector(double(travel(:))/(2*pi),F,nan);
elseif ~isempty(cycles)
    out.mechanical_cycles = local_fit_vector(double(cycles(:)),F,nan);
else
    out.mechanical_cycles = nan(F,1);
end
out.active_rmse_e_deg = local_vector_field(value, ...
    {'active_rmse_e_deg'},nan(F,1),F);
out.shadow_rmse_e_deg = local_vector_field(value, ...
    {'shadow_rmse_e_deg'},nan(F,1),F);
if all(~isfinite(out.active_rmse_e_deg))
    activeRad = local_numeric_field(value,{'active_rmse_e_rad'},[]);
    if ~isempty(activeRad)
        out.active_rmse_e_deg = rad2deg(local_fit_vector(activeRad,F,nan));
    end
end
if all(~isfinite(out.shadow_rmse_e_deg))
    shadowRad = local_numeric_field(value,{'shadow_rmse_e_rad'},[]);
    if ~isempty(shadowRad)
        out.shadow_rmse_e_deg = rad2deg(local_fit_vector(shadowRad,F,nan));
    end
end
if numel(out.reference_lut_e_rad) == M && ...
        all(isfinite(out.reference_lut_e_rad))
    reference = out.reference_lut_e_rad(:).';
    for q = 1:F
        if ~isfinite(out.active_rmse_e_deg(q))
            out.active_rmse_e_deg(q) = rad2deg(local_circular_rms( ...
                active(q,:)-reference));
        end
        if ~isfinite(out.shadow_rmse_e_deg(q)) && ...
                all(isfinite(shadow(q,:)))
            out.shadow_rmse_e_deg(q) = rad2deg(local_circular_rms( ...
                shadow(q,:)-reference));
        end
    end
end
out.valid = true;
out.reason = '';
end

function tableValue = local_learning_table(histories)
condition = strings(0,1); fusionEvent = zeros(0,1); timeS = zeros(0,1);
cycles = zeros(0,1); node = zeros(0,1); phi = zeros(0,1);
shadow = zeros(0,1); active = zeros(0,1); reference = zeros(0,1);
for k = 1:numel(histories)
    h = histories(k); if ~h.valid, continue; end
    [F,M] = size(h.active_lut_e_rad);
    for q = 1:F
        rows = (numel(node)+1):(numel(node)+M);
        condition(rows,1) = h.condition;
        fusionEvent(rows,1) = h.fusion_count(q);
        timeS(rows,1) = h.time_s(q);
        cycles(rows,1) = h.mechanical_cycles(q);
        node(rows,1) = (0:M-1).';
        phi(rows,1) = (0:M-1).'*2*pi/M;
        shadow(rows,1) = h.shadow_lut_e_rad(q,:).';
        active(rows,1) = h.active_lut_e_rad(q,:).';
        if numel(h.reference_lut_e_rad)==M
            reference(rows,1) = h.reference_lut_e_rad;
        else
            reference(rows,1) = nan(M,1);
        end
    end
end
tableValue = table(condition,fusionEvent,timeS,cycles,node,phi,shadow, ...
    active,reference,'VariableNames',{'condition','fusion_event','time_s', ...
    'mechanical_cycles','node','phi_m_rad','shadow_e_rad','active_e_rad', ...
    'reference_e_rad'});
end

function tableValue = local_rmse_table(histories)
condition = strings(0,1); fusionEvent = zeros(0,1); timeS = zeros(0,1);
cycles = zeros(0,1); shadow = zeros(0,1); active = zeros(0,1);
for k = 1:numel(histories)
    h = histories(k); if ~h.valid, continue; end
    F = size(h.active_lut_e_rad,1); rows=(numel(active)+1):(numel(active)+F);
    condition(rows,1)=h.condition; fusionEvent(rows,1)=h.fusion_count;
    timeS(rows,1)=h.time_s; cycles(rows,1)=h.mechanical_cycles;
    shadow(rows,1)=h.shadow_rmse_e_deg; active(rows,1)=h.active_rmse_e_deg;
end
tableValue=table(condition,fusionEvent,timeS,cycles,shadow,active, ...
    'VariableNames',{'condition','fusion_event','time_s', ...
    'mechanical_cycles','shadow_rmse_e_deg','active_rmse_e_deg'});
end

function [tableValue,reason] = local_noise_comparison(histories)
tableValue = table(); reason = 'Both zero-noise and noisy histories are required.';
[zeroIndex,noiseIndex] = local_noise_history_indices(histories);
if zeroIndex==0 || noiseIndex==0, return; end
z=histories(zeroIndex); n=histories(noiseIndex);
if ~z.valid || ~n.valid || size(z.active_lut_e_rad,2)~=size(n.active_lut_e_rad,2)
    reason='Zero-noise and noisy histories have incompatible node counts.'; return;
end
M=size(z.active_lut_e_rad,2); reference=nan(M,1);
if numel(z.reference_lut_e_rad)==M, reference=z.reference_lut_e_rad; ...
elseif numel(n.reference_lut_e_rad)==M, reference=n.reference_lut_e_rad; end
node=(0:M-1).'; phi=(0:M-1).'*2*pi/M;
zeroActive=z.active_lut_e_rad(end,:).'; noisyActive=n.active_lut_e_rad(end,:).';
zeroShadow=z.shadow_lut_e_rad(end,:).'; noisyShadow=n.shadow_lut_e_rad(end,:).';
tableValue=table(node,phi,reference,zeroShadow,zeroActive,noisyShadow, ...
    noisyActive,'VariableNames',{'node','phi_m_rad','reference_e_rad', ...
    'zero_noise_shadow_e_rad','zero_noise_active_e_rad', ...
    'noisy_shadow_e_rad','noisy_active_e_rad'});
reason='';
end

function [tableValue,reason] = local_noise_floor(comparison)
tableValue=table(); reason='No paired final noisy/zero-noise LUT is available.';
if isempty(comparison), return; end
signed=local_wrap(comparison.noisy_active_e_rad-comparison.zero_noise_active_e_rad);
absolute=abs(signed);
zeroError=local_wrap(comparison.zero_noise_active_e_rad-comparison.reference_e_rad);
noisyError=local_wrap(comparison.noisy_active_e_rad-comparison.reference_e_rad);
tableValue=table(comparison.node,comparison.phi_m_rad,signed,absolute, ...
    zeroError,noisyError,'VariableNames',{'node','phi_m_rad', ...
    'signed_noise_floor_e_rad','absolute_noise_floor_e_rad', ...
    'zero_noise_node_error_e_rad','noisy_node_error_e_rad'});
reason='';
end

function tableValue = local_normalize_sweeps(inputValue)
if isempty(inputValue)
    tableValue=table(strings(0,1),zeros(0,1),strings(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1),false(0,1),'VariableNames', ...
        {'sweep_family','value','condition','active_rmse_e_deg', ...
        'shadow_rmse_e_deg','fusion_count','finite'}); return;
end
if istable(inputValue), rows=table2struct(inputValue); else, rows=inputValue; end
assert(isstruct(rows),'anglelut:Stage4ReportSweeps', ...
    'sweeps must be a table or struct array.');
n=numel(rows); family=strings(n,1); value=zeros(n,1); condition=strings(n,1);
active=zeros(n,1); shadow=zeros(n,1); fusion=zeros(n,1); finite=false(n,1);
for k=1:n
    family(k)=local_text_field(rows(k),{'sweep_family','family','parameter'},'unknown');
    value(k)=local_scalar_field(rows(k),{'value','sweep_value'},NaN);
    condition(k)=local_text_field(rows(k),{'condition','case_id'},'unspecified');
    active(k)=local_scalar_field(rows(k),{'active_rmse_e_deg','active_rmse_deg'},NaN);
    shadow(k)=local_scalar_field(rows(k),{'shadow_rmse_e_deg','shadow_rmse_deg'},NaN);
    fusion(k)=local_scalar_field(rows(k),{'fusion_count','fusions'},NaN);
    finite(k)=local_logical_field(rows(k),{'finite','is_finite'}, ...
        all(isfinite([value(k),active(k),shadow(k)])));
end
tableValue=table(family,value,condition,active,shadow,fusion,finite, ...
    'VariableNames',{'sweep_family','value','condition','active_rmse_e_deg', ...
    'shadow_rmse_e_deg','fusion_count','finite'});
end

function tableValue = local_normalize_frozen(inputValue)
if isempty(inputValue)
    tableValue=local_empty_frozen_table(); return;
end
if istable(inputValue), rows=table2struct(inputValue); else, rows=inputValue; end
assert(isstruct(rows),'anglelut:Stage4ReportFrozen', ...
    'frozenMatrix must be a table or struct array.');
n=numel(rows); training=strings(n,1); evaluation=strings(n,1);
baseline=zeros(n,1); active=zeros(n,1); improvement=zeros(n,1); basis=strings(n,1);
id=zeros(n,1); prediction=zeros(n,1); torque=zeros(n,1); iq=zeros(n,1); meanTorque=zeros(n,1);
for k=1:n
    row=rows(k);
    training(k)=local_text_field(row,{'training_condition','train_condition'},'unknown');
    evaluation(k)=local_text_field(row,{'evaluation_condition','eval_condition'},'unknown');
    baseline(k)=local_nested_metric(row,'baseline', ...
        {'control_angle_rmse_e_deg','control_angle_rmse_deg'},NaN);
    active(k)=local_nested_metric(row,'active', ...
        {'control_angle_rmse_e_deg','control_angle_rmse_deg'},NaN);
    improvement(k)=local_scalar_field(row,{'control_angle_improvement'},NaN);
    if ~isfinite(improvement(k)) && isfinite(baseline(k)) && baseline(k)>0
        improvement(k)=1-active(k)/baseline(k);
    end
    basis(k)=local_text_field(row,{'control_angle_gate_basis','gate_basis'},'unspecified');
    id(k)=local_scalar_field(row,{'id_rms_improvement'},NaN);
    prediction(k)=local_scalar_field(row,{'prediction_residual_improvement'},NaN);
    torque(k)=local_scalar_field(row,{'torque_ripple_improvement'},NaN);
    iq(k)=local_scalar_field(row,{'iq_tracking_change'},NaN);
    meanTorque(k)=local_scalar_field(row,{'mean_torque_change'},NaN);
end
tableValue=table(training,evaluation,baseline,active,improvement,basis,id, ...
    prediction,torque,iq,meanTorque,'VariableNames', ...
    {'training_condition','evaluation_condition', ...
    'baseline_control_angle_rmse_e_deg','active_control_angle_rmse_e_deg', ...
    'control_angle_improvement','control_angle_gate_basis', ...
    'id_rms_improvement','prediction_residual_improvement', ...
    'torque_ripple_improvement','iq_tracking_change','mean_torque_change'});
end

function tableValue = local_normalize_comparisons(inputValue)
condition=strings(0,1); scheme=strings(0,1); rmse=zeros(0,1);
storage=zeros(0,1); operations=zeros(0,1);
if isempty(inputValue)
    tableValue=table(condition,scheme,rmse,storage,operations, ...
        'VariableNames',{'condition','scheme','active_rmse_e_deg', ...
        'storage_bytes','sample_ops_estimate'}); return;
end
if istable(inputValue), rows=table2struct(inputValue); else, rows=inputValue; end
assert(isstruct(rows),'anglelut:Stage4ReportComparisons', ...
    'schemeComparisons must be a table or struct array.');
schemeNames=["Scheme 4","Scheme 5","Scheme 2"];
rmseNames={{'scheme4_active_rmse_e_deg','scheme4_rmse_e_deg'}, ...
    {'scheme5_active_rmse_e_deg','scheme5_rmse_e_deg'}, ...
    {'scheme2_active_rmse_e_deg','scheme2_rmse_e_deg'}};
for k=1:numel(rows)
    for q=1:3
        condition(end+1,1)=local_text_field(rows(k),{'condition','case_id'},'unspecified'); %#ok<AGROW>
        scheme(end+1,1)=schemeNames(q); %#ok<AGROW>
        rmse(end+1,1)=local_scalar_field(rows(k),rmseNames{q},NaN); %#ok<AGROW>
        storage(end+1,1)=local_scheme_cost(rows(k),'storage_bytes',q); %#ok<AGROW>
        operations(end+1,1)=local_scheme_cost(rows(k),'sample_ops_estimate',q); %#ok<AGROW>
    end
end
tableValue=table(condition,scheme,rmse,storage,operations, ...
    'VariableNames',{'condition','scheme','active_rmse_e_deg', ...
    'storage_bytes','sample_ops_estimate'});
end

function [ok,reason] = local_draw_learning(fig,histories,titleText)
ok=false; reason='No valid active-LUT fusion history is available.';
index=local_primary_history(histories); if index==0, return; end
h=histories(index); [F,M]=size(h.active_lut_e_rad);
if F<1 || M<2, return; end
indices=unique(round(linspace(1,F,min(5,F)))); x=(0:M).'*360/M;
ax=axes(fig); hold(ax,'on'); grid(ax,'on');
plot(ax,x,zeros(M+1,1),':','Color',[0.5 0.5 0.5], ...
    'LineWidth',1.2,'DisplayName','zero LUT');
if numel(h.reference_lut_e_rad)==M
    plot(ax,x,rad2deg([h.reference_lut_e_rad;h.reference_lut_e_rad(1)]), ...
        'k','LineWidth',2,'DisplayName','evaluation reference');
end
blue=[0.10 0.42 0.78]; alpha=linspace(0.28,1,numel(indices));
for q=1:numel(indices)
    k=indices(q); tone=1-alpha(q)*(1-blue);
    plot(ax,x,rad2deg([h.active_lut_e_rad(k,:).';h.active_lut_e_rad(k,1)]), ...
        '-o','Color',tone,'MarkerSize',2,'LineWidth',1.2+0.4*(q==numel(indices)), ...
        'DisplayName',sprintf('fusion %g',h.fusion_count(k)));
end
xlabel(ax,'Raw mechanical angle (deg_m)'); ylabel(ax,'Correction (deg_e)');
title(ax,titleText+" - "+h.condition,'Interpreter','none');
legend(ax,'Location','best','Interpreter','none'); xlim(ax,[0 360]);
ok=true; reason='';
end

function [ok,reason] = local_draw_rmse(fig,T,titleText)
ok=~isempty(T) && any(isfinite(T.active_rmse_e_deg));
reason='Finite RMSE history is unavailable.'; if ~ok, return; end
conditions=unique(T.condition,'stable'); colors=[0.10 0.42 0.78;0.88 0.35 0.12;0.45 0.50 0.18];
layout=tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
xNames={'fusion_event','time_s','mechanical_cycles'};
xLabels={'Fusion event','Training time (s)','Mechanical cycles'};
for p=1:3
    ax=nexttile(layout); hold(ax,'on'); grid(ax,'on');
    ax.TickLabelInterpreter='none';
    for q=1:numel(conditions)
        rows=T.condition==conditions(q); color=colors(mod(q-1,size(colors,1))+1,:);
        x=T.(xNames{p})(rows); active=T.active_rmse_e_deg(rows);
        shadow=T.shadow_rmse_e_deg(rows); valid=isfinite(x)&isfinite(active);
        if any(valid)
            plot(ax,x(valid),active(valid),'-o','Color',color,'MarkerSize',3, ...
                'LineWidth',1.4,'DisplayName',conditions(q)+" active");
        end
        valid=isfinite(x)&isfinite(shadow);
        if any(valid)
            plot(ax,x(valid),shadow(valid),'--','Color',color,'LineWidth',1.1, ...
                'DisplayName',conditions(q)+" shadow");
        end
    end
    xlabel(ax,xLabels{p}); if p==1, ylabel(ax,'Circular LUT RMSE (deg_e)'); end
end
legend(nexttile(layout,1),'Location','best','Interpreter','none'); title(layout,titleText);
reason='';
end

function [ok,reason] = local_draw_noise_comparison(fig,T,titleText,defaultReason)
ok=~isempty(T); reason=defaultReason; if ~ok, return; end
M=height(T); x=(0:M).'*360/M; ax=axes(fig); hold(ax,'on'); grid(ax,'on');
plot(ax,x,zeros(M+1,1),':','Color',[0.5 0.5 0.5],'DisplayName','zero LUT');
if all(isfinite(T.reference_e_rad))
    plot(ax,x,rad2deg([T.reference_e_rad;T.reference_e_rad(1)]), ...
        'k','LineWidth',2,'DisplayName','evaluation reference');
end
plot(ax,x,rad2deg([T.zero_noise_active_e_rad;T.zero_noise_active_e_rad(1)]), ...
    '-o','Color',[0.10 0.42 0.78],'MarkerSize',3,'LineWidth',1.5, ...
    'DisplayName','zero-noise active');
plot(ax,x,rad2deg([T.noisy_active_e_rad;T.noisy_active_e_rad(1)]), ...
    '--s','Color',[0.88 0.35 0.12],'MarkerSize',3,'LineWidth',1.5, ...
    'DisplayName','noisy active');
xlabel(ax,'Raw mechanical angle (deg_m)'); ylabel(ax,'Correction (deg_e)');
title(ax,titleText); legend(ax,'Location','best'); xlim(ax,[0 360]); reason='';
end

function [ok,reason] = local_draw_frozen(fig,T,titleText)
ok=false; reason='A complete two-training by two-evaluation frozen matrix is unavailable.';
if isempty(T), return; end
train=unique(T.training_condition,'stable'); evaluation=unique(T.evaluation_condition,'stable');
if numel(train)~=2 || numel(evaluation)~=2, return; end
values=nan(2,2);
for r=1:2
    for c=1:2
        row=find(T.training_condition==train(r)&T.evaluation_condition==evaluation(c),1);
        if ~isempty(row), values(r,c)=100*T.control_angle_improvement(row); end
    end
end
if nnz(isfinite(values))~=4, return; end
ax=axes(fig); image(ax,values,'CDataMapping','scaled'); colormap(ax,local_blue_map());
colorbar(ax); xticks(ax,1:2); xticklabels(ax,evaluation); yticks(ax,1:2); yticklabels(ax,train);
ax.TickLabelInterpreter='none';
xlabel(ax,'Evaluation condition'); ylabel(ax,'Training condition');
for r=1:2
    for c=1:2
        text(ax,c,r,sprintf('%.1f%%',values(r,c)),'HorizontalAlignment','center', ...
            'FontWeight','bold','Color','k');
    end
end
title(ax,string(titleText)+" - control-angle RMSE improvement"); ok=true; reason='';
end

function [ok,reason] = local_draw_noise_floor(fig,T,titleText,defaultReason)
ok=~isempty(T); reason=defaultReason; if ~ok, return; end
layout=tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
ax=nexttile(layout); bar(ax,T.node,rad2deg(T.absolute_noise_floor_e_rad),1, ...
    'FaceColor',[0.10 0.42 0.78],'EdgeColor','none'); grid(ax,'on');
ylabel(ax,'|noisy - zero| (deg_e)');
ax=nexttile(layout); hold(ax,'on'); grid(ax,'on');
plot(ax,T.node,rad2deg(abs(T.zero_noise_node_error_e_rad)),'-', ...
    'Color',[0.10 0.42 0.78],'DisplayName','zero-noise error');
plot(ax,T.node,rad2deg(abs(T.noisy_node_error_e_rad)),'--', ...
    'Color',[0.88 0.35 0.12],'DisplayName','noisy error');
xlabel(ax,'LUT node'); ylabel(ax,'Absolute node error (deg_e)'); legend(ax,'Location','best');
title(layout,titleText); reason='';
end

function [ok,reason] = local_draw_sweeps(fig,T,titleText)
valid=T.finite & isfinite(T.value) & isfinite(T.active_rmse_e_deg);
ok=any(valid); reason='No finite OFAT sweep rows are available.'; if ~ok, return; end
families=unique(T.sweep_family(valid),'stable'); count=numel(families);
cols=min(3,count); rows=ceil(count/cols);
layout=tiledlayout(fig,rows,cols,'TileSpacing','compact','Padding','compact');
colors=[0.10 0.42 0.78;0.88 0.35 0.12;0.45 0.50 0.18];
for f=1:count
    ax=nexttile(layout); hold(ax,'on'); grid(ax,'on'); family=families(f);
    ax.TickLabelInterpreter='none';
    conditions=unique(T.condition(valid&T.sweep_family==family),'stable');
    for q=1:numel(conditions)
        mask=valid&T.sweep_family==family&T.condition==conditions(q);
        [x,order]=sort(T.value(mask)); a=T.active_rmse_e_deg(mask); s=T.shadow_rmse_e_deg(mask);
        a=a(order); s=s(order); color=colors(mod(q-1,size(colors,1))+1,:);
        plot(ax,x,a,'-o','Color',color,'LineWidth',1.4, ...
            'DisplayName',conditions(q)+" active");
        if any(isfinite(s)), plot(ax,x,s,'--','Color',color,'LineWidth',1.0, ...
                'DisplayName',conditions(q)+" shadow"); end
    end
    xlabel(ax,'Sweep value'); ylabel(ax,'LUT RMSE (deg_e)'); title(ax,family,'Interpreter','none');
    legend(ax,'Location','best','Interpreter','none');
end
title(layout,titleText); reason='';
end

function [ok,reason] = local_draw_comparison(fig,T,titleText)
ok=~isempty(T) && any(isfinite(T.active_rmse_e_deg));
reason='Scheme 4/5/2 comparison data is unavailable.'; if ~ok, return; end
schemes=["Scheme 4","Scheme 5","Scheme 2"];
colors=[0.10 0.42 0.78;0.88 0.35 0.12;0.45 0.50 0.18];
conditions=unique(T.condition,'stable'); rmse=nan(numel(conditions),3);
storage=nan(1,3); operations=nan(1,3);
for q=1:3
    for k=1:numel(conditions)
        row=find(T.condition==conditions(k)&T.scheme==schemes(q),1);
        if ~isempty(row), rmse(k,q)=T.active_rmse_e_deg(row); end
    end
    storage(q)=local_finite_median(T.storage_bytes(T.scheme==schemes(q)));
    operations(q)=local_finite_median(T.sample_ops_estimate(T.scheme==schemes(q)));
end
layout=tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
ax=nexttile(layout); grid(ax,'on'); ax.TickLabelInterpreter='none';
if isscalar(conditions)
    bars=bar(ax,rmse(1,:),'FaceColor','flat'); bars.CData=colors;
    xticks(ax,1:3); xticklabels(ax,schemes); xtickangle(ax,30);
else
    bars=bar(ax,rmse);
    for q=1:min(3,numel(bars)), bars(q).FaceColor=colors(q,:); end
    xticks(ax,1:numel(conditions)); xticklabels(ax,conditions); xtickangle(ax,30);
    legend(ax,schemes,'Location','best');
end
ylabel(ax,'Active LUT RMSE (deg_e)');
ax=nexttile(layout); b=bar(ax,storage,'FaceColor','flat'); b.CData=colors; grid(ax,'on');
xticks(ax,1:3); xticklabels(ax,schemes); xtickangle(ax,30); ylabel(ax,'Fixed state (bytes)');
ax=nexttile(layout); b=bar(ax,operations,'FaceColor','flat'); b.CData=colors; grid(ax,'on');
xticks(ax,1:3); xticklabels(ax,schemes); xtickangle(ax,30); ylabel(ax,'Estimated operations / sample');
title(layout,titleText); reason='';
end

function entry = local_export_report(fig,outputDir,name,available,reason,data)
entry=local_empty_entry(); entry.name=name; entry.available=logical(available);
entry.reason=reason; entry.png=fullfile(outputDir,[name '.png']);
entry.pdf=fullfile(outputDir,[name '.pdf']); entry.csv=fullfile(outputDir,[name '.csv']);
entry.json=fullfile(outputDir,[name '.json']);
exportgraphics(fig,entry.png,'Resolution',160);
exportgraphics(fig,entry.pdf,'ContentType','vector');
local_write_dataset(data,entry.csv,entry.json,available,reason,name);
entry.png_bytes=local_file_bytes(entry.png); entry.pdf_bytes=local_file_bytes(entry.pdf);
entry.csv_bytes=local_file_bytes(entry.csv); entry.json_bytes=local_file_bytes(entry.json);
end

function local_write_dataset(data,csvPath,jsonPath,available,reason,name)
if isempty(data)
    csvData=table(logical(available),string(reason), ...
        'VariableNames',{'available','reason'});
else
    csvData=data;
end
writetable(csvData,csvPath);
payload=struct('schema_version',[name '-v1'],'available',logical(available), ...
    'reason',reason,'rows',table2struct(data));
write_json_file(jsonPath,payload);
end

function local_write_learning_gif(histories,placeholderFigure,path)
index=local_primary_history(histories);
if index==0
    local_append_gif_frame(placeholderFigure,path,true); return;
end
h=histories(index); [F,M]=size(h.active_lut_e_rad);
if F==0 || M<2, local_append_gif_frame(placeholderFigure,path,true); return; end
frameFigure=figure('Visible','off','Color','w','Position',[100 100 950 580]);
cleanup=onCleanup(@()close(frameFigure));
indices=unique(round(linspace(1,F,min(F,30)))); x=(0:M).'*360/M;
ax=axes(frameFigure);
for q=1:numel(indices)
    k=indices(q); cla(ax,'reset'); hold(ax,'on'); grid(ax,'on');
    plot(ax,x,zeros(M+1,1),':','Color',[0.5 0.5 0.5], ...
        'LineWidth',1.2,'DisplayName','zero LUT');
    if numel(h.reference_lut_e_rad)==M
        plot(ax,x,rad2deg([h.reference_lut_e_rad;h.reference_lut_e_rad(1)]), ...
            'k','LineWidth',2,'DisplayName','evaluation reference');
    end
    if all(isfinite(h.shadow_lut_e_rad(k,:)))
        plot(ax,x,rad2deg([h.shadow_lut_e_rad(k,:).';h.shadow_lut_e_rad(k,1)]), ...
            '--','Color',[0.88 0.35 0.12],'LineWidth',1.3,'DisplayName','shadow');
    end
    plot(ax,x,rad2deg([h.active_lut_e_rad(k,:).';h.active_lut_e_rad(k,1)]), ...
        '-o','Color',[0.10 0.42 0.78],'MarkerSize',3,'LineWidth',1.6, ...
        'DisplayName','active');
    xlabel(ax,'Raw mechanical angle (deg_m)'); ylabel(ax,'Correction (deg_e)');
    title(ax,sprintf('%s - fusion %g/%g, active RMSE %.3g deg_e', ...
        h.condition,h.fusion_count(k),h.fusion_count(end),h.active_rmse_e_deg(k)), ...
        'Interpreter','none');
    legend(ax,'Location','best'); xlim(ax,[0 360]);
    local_append_gif_frame(frameFigure,path,q==1);
end
clear cleanup;
end

function local_append_gif_frame(fig,path,isFirst)
temporary=[tempname '.png']; exportgraphics(fig,temporary,'Resolution',100);
cleanup=onCleanup(@()local_delete_if_present(temporary));
[image,map]=rgb2ind(imread(temporary),256);
if isFirst
    imwrite(image,map,path,'gif','LoopCount',inf,'DelayTime',0.25);
else
    imwrite(image,map,path,'gif','WriteMode','append','DelayTime',0.25);
end
clear cleanup;
end

function index = local_primary_history(histories)
index=0;
for k=1:numel(histories)
    if histories(k).valid && local_is_zero_noise(histories(k).condition)
        index=k; return;
    end
end
for k=1:numel(histories)
    if histories(k).valid, index=k; return; end
end
end

function [zeroIndex,noiseIndex] = local_noise_history_indices(histories)
zeroIndex=0; noiseIndex=0;
for k=1:numel(histories)
    if ~histories(k).valid, continue; end
    condition=lower(histories(k).condition);
    if local_is_zero_noise(condition)
        zeroIndex=k;
    elseif contains(condition,'noise') || contains(condition,'noisy')
        noiseIndex=k;
    end
end
if (zeroIndex==0 || noiseIndex==0) && numel(histories)==2
    valid=find([histories.valid]);
    if numel(valid)==2
        if zeroIndex==0, zeroIndex=valid(valid~=noiseIndex); end
        if noiseIndex==0, noiseIndex=valid(valid~=zeroIndex); end
    end
end
end

function value = local_is_zero_noise(condition)
condition=lower(string(condition));
value=contains(condition,'zero_noise') || contains(condition,'no_noise') || ...
    condition=="zero" || condition=="ideal";
end

function value = local_scheme_cost(row,fieldName,index)
value=NaN;
if ~isfield(row,fieldName)
    schemePrefixes={'scheme4','scheme5','scheme2'};
    flattenedName=[schemePrefixes{index} '_' fieldName];
    value=local_scalar_field(row,{flattenedName},NaN);
    return;
end
source=row.(fieldName);
if isnumeric(source)
    source=double(source(:));
    if numel(source)>=index, value=source(index); elseif isscalar(source), value=source; end
elseif isstruct(source)
    names={{'scheme4','scheme_4','s4'},{'scheme5','scheme_5','s5'}, ...
        {'scheme2','scheme_2','s2'}};
    value=local_scalar_field(source,names{index},NaN);
end
end

function value = local_nested_metric(row,parentName,names,defaultValue)
value=defaultValue;
if ~isfield(row,parentName), return; end
source=row.(parentName);
if isstruct(source), value=local_scalar_field(source,names,defaultValue); ...
elseif isnumeric(source)&&isscalar(source), value=double(source); end
end

function value = local_numeric_field(valueStruct,names,defaultValue)
value=defaultValue;
for k=1:numel(names)
    if isfield(valueStruct,names{k})
        candidate=valueStruct.(names{k});
        if isnumeric(candidate) || islogical(candidate), value=double(candidate); end
        return;
    end
end
end

function value = local_scalar_field(valueStruct,names,defaultValue)
candidate=local_numeric_field(valueStruct,names,defaultValue);
if isempty(candidate)
    value=defaultValue;
elseif isnumeric(candidate)
    value=double(candidate(1));
else
    value=defaultValue;
end
end

function value = local_logical_field(valueStruct,names,defaultValue)
value=defaultValue;
for k=1:numel(names)
    if isfield(valueStruct,names{k})
        candidate=valueStruct.(names{k});
        if islogical(candidate)||isnumeric(candidate), value=logical(candidate(1)); end
        return;
    end
end
end

function value = local_text_field(valueStruct,names,defaultValue)
value=string(defaultValue);
for k=1:numel(names)
    if isfield(valueStruct,names{k})
        candidate=valueStruct.(names{k});
        if ischar(candidate) || (isstring(candidate)&&isscalar(candidate)) || ...
                (iscategorical(candidate)&&isscalar(candidate))
            value=string(candidate);
        end
        break;
    end
end
value=char(value);
end

function value = local_vector_field(valueStruct,names,defaultValue,count)
value=local_numeric_field(valueStruct,names,defaultValue);
value=local_fit_vector(value,count,nan);
end

function value = local_fit_vector(value,count,fillValue)
value=double(value(:));
if isempty(value)
    value=fillValue*ones(count,1);
elseif isscalar(value)&&count>1
    value=(value+(0:count-1)).';
elseif numel(value)<count
    value=[value;fillValue*ones(count-numel(value),1)];
elseif numel(value)>count
    value=value(1:count);
end
end

function value = local_diagnostic_outcome(result)
value='';
if ~isfield(result,'diagnostic_outcome'), return; end
candidate=result.diagnostic_outcome;
if ischar(candidate)||(isstring(candidate)&&isscalar(candidate))
    value=char(candidate);
elseif isstruct(candidate)
    value=local_text_field(candidate,{'outcome','status','summary'},'available');
end
end

function value = local_circular_rms(x)
x=local_wrap(double(x(:))); value=sqrt(mean(x.^2,'omitnan'));
end

function value = local_wrap(x)
value=atan2(sin(double(x)),cos(double(x)));
end

function value = local_finite_median(x)
x=double(x(:)); x=x(isfinite(x));
if isempty(x), value=NaN; else, value=median(x); end
end

function value = local_file_bytes(path)
info=dir(path); if isempty(info), value=0; else, value=double(info(1).bytes); end
end

function local_placeholder(fig,titleText,reason)
clf(fig); ax=axes(fig); axis(ax,[0 1 0 1]); axis(ax,'off');
text(ax,0.5,0.58,titleText,'HorizontalAlignment','center', ...
    'FontSize',16,'FontWeight','bold','Interpreter','none');
text(ax,0.5,0.44,'Unavailable in this partial or BLOCKED run', ...
    'HorizontalAlignment','center','FontSize',12,'Color',[0.35 0.35 0.35]);
text(ax,0.5,0.34,reason,'HorizontalAlignment','center','FontSize',10, ...
    'Color',[0.45 0.45 0.45],'Interpreter','none');
end

function fig = local_figure()
fig=figure('Visible','off','Color','w','Position',[100 100 1150 680]);
end

function value = local_blue_map()
t=linspace(0,1,256).'; value=[0.94-0.65*t,0.97-0.52*t,1-0.20*t];
end

function value = local_empty_history()
value=struct('condition',"",'fusion_count',zeros(0,1), ...
    'time_s',zeros(0,1),'mechanical_cycles',zeros(0,1), ...
    'shadow_lut_e_rad',zeros(0,0),'active_lut_e_rad',zeros(0,0), ...
    'shadow_rmse_e_deg',zeros(0,1),'active_rmse_e_deg',zeros(0,1), ...
    'reference_lut_e_rad',zeros(0,1),'valid',false,'reason','');
end

function value = local_empty_entry()
value=struct('name','','available',false,'reason','','png','','pdf','', ...
    'gif','','csv','','json','','png_bytes',0,'pdf_bytes',0, ...
    'gif_bytes',0,'csv_bytes',0,'json_bytes',0);
end

function value = local_empty_frozen_table()
value=table(strings(0,1),strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    'VariableNames',{'training_condition','evaluation_condition', ...
    'baseline_control_angle_rmse_e_deg','active_control_angle_rmse_e_deg', ...
    'control_angle_improvement','control_angle_gate_basis', ...
    'id_rms_improvement','prediction_residual_improvement', ...
    'torque_ripple_improvement','iq_tracking_change','mean_torque_change'});
end

function local_delete_if_present(path)
if isfile(path), delete(path); end
end

function value = local_iso_time()
value=char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
