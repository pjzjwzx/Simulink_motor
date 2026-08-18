function report = generate_stage1_reports(outDir,cfg)
%GENERATE_STAGE1_REPORTS Create deterministic, evaluation-only Stage-1 reports.
%   REPORT = GENERATE_STAGE1_REPORTS(OUTDIR,CFG) reads completed or partial
%   case artifacts below OUTDIR/cases and writes report artifacts below
%   OUTDIR/reports.  It never changes gate.json, case metrics, the model, or
%   any deployment result.  Truth data is consumed only for offline scoring
%   and the evaluation-only reference LUT.
%
%   Missing cases or fields produce explicit placeholder figures and
%   available=false metadata instead of changing a mathematical gate.

if nargin < 1 || strlength(string(outDir)) == 0
    error('anglelut:Stage1ReportOutDir','A Stage-1 output directory is required.');
end
outDir = char(string(outDir));
assert(isfolder(outDir),'anglelut:Stage1ReportOutDir', ...
    'Stage-1 output directory does not exist: %s',outDir);
if nargin < 2 || isempty(cfg)
    cfg = local_resolve_config(outDir);
end

reportDir = fullfile(outDir,'reports');
if ~isfolder(reportDir), mkdir(reportDir); end

inventory = local_case_inventory(outDir);
metrics = local_read_metrics(outDir,inventory);
[gate,gateAvailable,gateReason] = local_read_json(fullfile(outDir,'gate.json'));
[primaryTrace,primaryCase,primaryCaseCfg,primaryReason] = ...
    local_select_primary_trace(inventory);

artifacts = repmat(local_artifact_template(),0,1);

% Time-alignment evidence and timeline.
[alignmentTable,alignmentMeta] = local_time_alignment( ...
    primaryTrace,primaryCase,primaryCaseCfg,cfg);
writetable(alignmentTable,fullfile(reportDir,'time_alignment_report.csv'));
write_json_file(fullfile(reportDir,'time_alignment_report.json'), ...
    struct('schema_version','stage1-time-alignment-report-v1', ...
    'available',alignmentMeta.available, ...
    'source_case_id',char(primaryCase), ...
    'reason',alignmentMeta.reason, ...
    'rows',table2struct(alignmentTable)));
[timelineAvailable,timelineReason] = local_export_plot( ...
    @() local_plot_timing(alignmentTable,cfg),reportDir, ...
    'timing_timeline',alignmentMeta.available,alignmentMeta.reason);
artifacts(end+1,1) = local_artifact('timing_timeline', ...
    timelineAvailable,timelineReason,primaryCase, ...
    ["timing_timeline.png","timing_timeline.pdf"]);
artifacts(end+1,1) = local_artifact('time_alignment_report', ...
    alignmentMeta.available,alignmentMeta.reason,primaryCase, ...
    ["time_alignment_report.csv","time_alignment_report.json"]);

% y_d-y_q trajectory, preferring periodic_combined.
[ydq,ydqAvailable,ydqReason] = local_extract_ydq(primaryTrace);
[plotAvailable,plotReason] = local_export_plot( ...
    @() local_plot_ydq(ydq,primaryCase),reportDir, ...
    'yd_yq_trajectory',ydqAvailable,local_join_reason(primaryReason,ydqReason));
artifacts(end+1,1) = local_artifact('yd_yq_trajectory', ...
    plotAvailable,plotReason,primaryCase, ...
    ["yd_yq_trajectory.png","yd_yq_trajectory.pdf"]);

% Residual amplitude versus available speed across all readable cases.
[speedData,speedAvailable,speedReason] = ...
    local_collect_residual_speed(inventory,cfg);
[plotAvailable,plotReason] = local_export_plot( ...
    @() local_plot_residual_speed(speedData,cfg),reportDir, ...
    'residual_amplitude_vs_speed',speedAvailable,speedReason);
artifacts(end+1,1) = local_artifact('residual_amplitude_vs_speed', ...
    plotAvailable,plotReason,"", ...
    ["residual_amplitude_vs_speed.png", ...
    "residual_amplitude_vs_speed.pdf"]);

% Forward/reverse, speed, and load consistency from persisted metrics.
[consistency,consistencyAvailable,consistencyReason] = ...
    local_condition_consistency(metrics);
[plotAvailable,plotReason] = local_export_plot( ...
    @() local_plot_condition_consistency(consistency),reportDir, ...
    'condition_consistency',consistencyAvailable,consistencyReason);
artifacts(end+1,1) = local_artifact('condition_consistency', ...
    plotAvailable,plotReason,"", ...
    ["condition_consistency.png","condition_consistency.pdf"]);

% Error budget table.  Values are observations, not new acceptance limits.
[errorBudget,errorMeta] = local_error_budget(metrics);
writetable(errorBudget,fullfile(reportDir,'error_budget.csv'));
write_json_file(fullfile(reportDir,'error_budget.json'), ...
    struct('schema_version','stage1-error-budget-v1', ...
    'available',errorMeta.available, ...
    'reference_case_id',char(errorMeta.reference_case_id), ...
    'reference_rmse_e_deg',errorMeta.reference_rmse_e_deg, ...
    'reason',errorMeta.reason, ...
    'rows',table2struct(errorBudget)));
artifacts(end+1,1) = local_artifact('error_budget', ...
    errorMeta.available,errorMeta.reason,errorMeta.reference_case_id, ...
    ["error_budget.csv","error_budget.json"]);

% Evaluation-only reference LUT on the raw mechanical-angle index.
[referenceLut,referenceMetadata,referenceTable] = ...
    local_reference_lut(primaryTrace,primaryCase,cfg);
writetable(referenceTable,fullfile(reportDir,'reference_lut.csv'));
save(fullfile(reportDir,'reference_lut.mat'), ...
    'referenceLut','referenceMetadata');
[plotAvailable,plotReason] = local_export_plot( ...
    @() local_plot_reference_lut(referenceLut,referenceMetadata), ...
    reportDir,'reference_lut',referenceMetadata.available, ...
    referenceMetadata.reason);
artifacts(end+1,1) = local_artifact('reference_lut', ...
    plotAvailable,plotReason,primaryCase, ...
    ["reference_lut.csv","reference_lut.mat", ...
    "reference_lut.png","reference_lut.pdf"]);

% Gate failures are a read-only transcription of the existing gate file.
[gateReport,gateText] = local_gate_failures(gate,gateAvailable,gateReason);
write_json_file(fullfile(reportDir,'gate_failures.json'),gateReport);
local_write_text(fullfile(reportDir,'gate_failures.txt'),gateText);
artifacts(end+1,1) = local_artifact('gate_failures', ...
    gateReport.available,gateReport.reason,"", ...
    ["gate_failures.json","gate_failures.txt"]);

report = struct();
report.schema_version = 'stage1-report-bundle-v1';
report.out_dir = outDir;
report.report_dir = reportDir;
report.generation_status = 'COMPLETE';
report.offline_evaluation_only = true;
report.mathematical_gate_modified = false;
report.case_count_discovered = numel(inventory);
report.metrics_available = ~isempty(metrics);
report.primary_case_id = char(primaryCase);
report.artifacts = artifacts;
write_json_file(fullfile(reportDir,'report_manifest.json'),report);
end

function cfg = local_resolve_config(outDir)
cfg = [];
[configuration,available] = local_read_json(fullfile(outDir,'configuration.json'));
if available && isfield(configuration,'default_config')
    cfg = configuration.default_config;
end
if isempty(cfg)
    cfg = default_config();
end
end

function inventory = local_case_inventory(outDir)
template = struct('case_id',"",'case_dir',"",'trace_path',"", ...
    'metrics_path',"",'config_path',"",'trace_available',false);
inventory = repmat(template,0,1);
caseRoot = fullfile(outDir,'cases');
if ~isfolder(caseRoot), return; end
entries = dir(caseRoot);
entries = entries([entries.isdir] & ~ismember({entries.name},{'.','..'}));
[~,order] = sort(lower(string({entries.name})));
entries = entries(order);
for k = 1:numel(entries)
    item = template;
    item.case_id = string(entries(k).name);
    item.case_dir = string(fullfile(entries(k).folder,entries(k).name));
    item.trace_path = string(fullfile(item.case_dir,'trace.mat'));
    item.metrics_path = string(fullfile(item.case_dir,'metrics.json'));
    item.config_path = string(fullfile(item.case_dir,'case_config.json'));
    item.trace_available = isfile(item.trace_path);
    inventory(end+1,1) = item; %#ok<AGROW>
end
end

function metrics = local_read_metrics(outDir,inventory)
canonicalNames = {'case_id','group','expected_class','rmse_e_deg', ...
    'mean_estimation_error_e_deg','valid_fraction', ...
    'predictor_floor_e_deg','voltage_reconstruction_rms_V'};
metricsPath = fullfile(outDir,'metrics.csv');
if isfile(metricsPath)
    try
        raw = readtable(metricsPath,'TextType','string', ...
            'VariableNamingRule','preserve');
        metrics = local_canonical_metrics(raw,canonicalNames);
        return;
    catch
    end
end

rows = repmat(local_metric_row_template(),0,1);
for k = 1:numel(inventory)
    [value,available] = local_read_json(char(inventory(k).metrics_path));
    if ~available, continue; end
    row = local_metric_row_template();
    for name = canonicalNames
        if isfield(value,name{1}), row.(name{1}) = value.(name{1}); end
    end
    if strlength(string(row.case_id)) == 0
        row.case_id = char(inventory(k).case_id);
    end
    rows(end+1,1) = row; %#ok<AGROW>
end
if isempty(rows)
    metrics = table();
else
    metrics = struct2table(rows,'AsArray',true);
    metrics.case_id = string(metrics.case_id);
    metrics.group = string(metrics.group);
    metrics.expected_class = string(metrics.expected_class);
end
end

function metrics = local_canonical_metrics(raw,names)
n = height(raw);
metrics = table(strings(n,1),strings(n,1),strings(n,1), ...
    NaN(n,1),NaN(n,1),NaN(n,1),NaN(n,1),NaN(n,1), ...
    'VariableNames',names);
metrics.case_id = local_table_string(raw,'case_id',n);
metrics.group = local_table_string(raw,'group',n);
metrics.expected_class = local_table_string(raw,'expected_class',n);
for name = names(4:end)
    metrics.(name{1}) = local_table_double(raw,name{1},n);
end
end

function row = local_metric_row_template()
row = struct('case_id','', 'group','', 'expected_class','', ...
    'rmse_e_deg',NaN, 'mean_estimation_error_e_deg',NaN, ...
    'valid_fraction',NaN, 'predictor_floor_e_deg',NaN, ...
    'voltage_reconstruction_rms_V',NaN);
end

function value = local_table_string(source,name,n)
if any(strcmp(source.Properties.VariableNames,name))
    value = string(source.(name));
    value = reshape(value,[],1);
else
    value = strings(n,1);
end
end

function value = local_table_double(source,name,n)
if ~any(strcmp(source.Properties.VariableNames,name))
    value = NaN(n,1);
    return;
end
raw = source.(name);
if isnumeric(raw) || islogical(raw)
    value = double(raw(:));
else
    value = str2double(string(raw(:)));
end
end

function [trace,caseId,caseCfg,reason] = local_select_primary_trace(inventory)
trace = struct();
caseId = "";
caseCfg = struct();
reason = 'No readable case trace was found.';
if isempty(inventory), return; end
ids = string({inventory.case_id});
preferred = find(ids == "periodic_combined",1);
order = [preferred, setdiff(1:numel(inventory),preferred,'stable')];
for index = order
    if isempty(index) || ~inventory(index).trace_available, continue; end
    [candidate,available,loadReason] = ...
        local_load_trace(char(inventory(index).trace_path));
    if available && local_trace_has_samples(candidate)
        trace = candidate;
        caseId = inventory(index).case_id;
        [caseCfg,cfgAvailable] = ...
            local_read_json(char(inventory(index).config_path));
        if ~cfgAvailable, caseCfg = struct(); end
        reason = '';
        return;
    end
    reason = loadReason;
end
end

function tf = local_trace_has_samples(trace)
tf = isstruct(trace) && isscalar(trace) && ...
    ((isfield(trace,'time_s') && ~isempty(trace.time_s)) || ...
    (isfield(trace,'valid') && ~isempty(trace.valid)));
if ~tf, return; end
if isfield(trace,'valid')
    raw = double(trace.valid(:));
    accepted = isfinite(raw) & raw ~= 0;
    if isfield(trace,'evaluation_mask')
        evaluation = double(trace.evaluation_mask(:));
        n = min(numel(accepted),numel(evaluation));
        accepted = accepted(1:n) & isfinite(evaluation(1:n)) & ...
            evaluation(1:n) ~= 0;
    end
    tf = any(accepted);
end
end

function [trace,available,reason] = local_load_trace(path)
trace = struct();
available = false;
reason = 'trace.mat is missing.';
if ~isfile(path), return; end
try
    loaded = load(path,'trace');
    if isfield(loaded,'trace') && isstruct(loaded.trace)
        trace = loaded.trace;
        available = true;
        reason = '';
    else
        reason = 'trace.mat does not contain a trace structure.';
    end
catch ME
    reason = sprintf('trace.mat could not be read: %s',ME.message);
end
end

function [alignment,meta] = local_time_alignment(trace,caseId,caseCfg,cfg)
event = strings(0,1); scope = strings(0,1); expected_s = zeros(0,1);
observed_s = zeros(0,1); error_s = zeros(0,1); tolerance_s = zeros(0,1);
within_tolerance = false(0,1); available = false(0,1);
source_case_id = strings(0,1); note = strings(0,1);

T = local_cfg_number(cfg,{'timing','T_ident_s'},50e-6);
offset = local_cfg_number(cfg,{'timing','identification_event_offset_s'},5e-6);
tol = local_cfg_number(cfg,{'timing','timestamp_tolerance_s'},2.5e-6);
contractEvents = ["duty_effective_start","adc_boundary_sample", ...
    "encoder_boundary_sample","identification_event","next_pwm_boundary"];
contractOffsets = [0,0,0,offset,T];
for k = 1:numel(contractEvents)
    append(contractEvents(k),"contract",contractOffsets(k), ...
        contractOffsets(k),tol,true,"configured timing contract");
end

measuredNames = ["identification_interval","availability_latency", ...
    "current_timestamp_offset","voltage_timestamp_offset", ...
    "angle_timestamp_offset"];
measuredExpected = [T,offset + local_struct_number(caseCfg, ...
    'extra_sensor_delay_s',0),0,0,0];
measuredObserved = NaN(size(measuredExpected));
measuredAvailable = false(size(measuredExpected));
if isstruct(trace) && isfield(trace,'IdentificationBus')
    bus = trace.IdentificationBus;
    timestamp = local_struct_column(bus,'timestamp_s');
    if numel(timestamp) >= 2
        measuredObserved(1) = median(diff(timestamp),'omitnan');
        measuredAvailable(1) = isfinite(measuredObserved(1));
    end
    if isfield(trace,'availability_time_s') && isfield(trace,'time_s')
        a = double(trace.availability_time_s(:));
        t = double(trace.time_s(:));
        n = min(numel(a),numel(t));
        measuredObserved(2) = local_finite_median(a(1:n)-t(1:n));
        measuredAvailable(2) = isfinite(measuredObserved(2));
    end
    fields = {'current_timestamp_s','voltage_timestamp_s','angle_timestamp_s'};
    for k = 1:numel(fields)
        values = local_struct_column(bus,fields{k});
        n = min(numel(values),numel(timestamp));
        if n > 0
            measuredObserved(k+2) = ...
                local_finite_median(values(1:n)-timestamp(1:n));
            measuredAvailable(k+2) = isfinite(measuredObserved(k+2));
        end
    end
end
for k = 1:numel(measuredNames)
    append(measuredNames(k),"measured",measuredExpected(k), ...
        measuredObserved(k),tol,measuredAvailable(k), ...
        "median over persisted IdentificationBus records");
end

alignment = table(event,scope,expected_s,observed_s,error_s,tolerance_s, ...
    within_tolerance,available,source_case_id,note);
meta.available = any(available(scope=="measured"));
if meta.available
    meta.reason = '';
elseif strlength(caseId) == 0
    meta.reason = 'No case trace was available for measured alignment.';
else
    meta.reason = 'The selected trace lacks timestamp alignment fields.';
end

    function append(name,rowScope,expected,observed,rowTolerance,rowAvailable,rowNote)
        event(end+1,1) = name;
        scope(end+1,1) = rowScope;
        expected_s(end+1,1) = expected;
        observed_s(end+1,1) = observed;
        if rowAvailable
            error_s(end+1,1) = observed-expected;
            within_tolerance(end+1,1) = abs(observed-expected) <= rowTolerance;
        else
            error_s(end+1,1) = NaN;
            within_tolerance(end+1,1) = false;
        end
        tolerance_s(end+1,1) = rowTolerance;
        available(end+1,1) = rowAvailable;
        source_case_id(end+1,1) = caseId;
        note(end+1,1) = rowNote;
    end
end

function fig = local_plot_timing(alignment,cfg)
fig = local_new_figure();
layout = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
title(layout,'Stage 1 timing timeline','FontWeight','bold');

contract = alignment(alignment.scope=="contract" & alignment.available,:);
ax = nexttile(layout);
if isempty(contract)
    local_axes_message(ax,'Configured timing contract is unavailable.');
else
    x = 1e6*contract.observed_s;
    y = (1:height(contract)).';
    stem(ax,x,y,'filled','Color',local_color('blue'),'LineWidth',1.2);
    ax.YTick = y;
    ax.YTickLabel = strrep(cellstr(contract.event),'_',' ');
    ax.YDir = 'reverse';
    xlabel(ax,'offset within PWM interval (us)');
    subtitle(ax,sprintf('Configured T_{ident} = %.3f us', ...
        1e6*local_cfg_number(cfg,{'timing','T_ident_s'},50e-6)));
    local_style_axes(ax);
end

measured = alignment(alignment.scope=="measured" & alignment.available,:);
ax = nexttile(layout);
if isempty(measured)
    local_axes_message(ax,'Measured alignment unavailable; contract-only report.');
else
    values = 1e6*measured.error_s;
    bar(ax,1:numel(values),values,0.62,'FaceColor',local_color('blue'), ...
        'EdgeColor',local_color('ink'));
    hold(ax,'on');
    yline(ax,0,'-','Color',local_color('ink'));
    plot(ax,1:numel(values),values,'o','Color',local_color('blue'), ...
        'MarkerFaceColor','w','MarkerSize',5,'LineWidth',1);
    tolerance = 1e6*max(measured.tolerance_s);
    yline(ax,tolerance,'--','Color',local_color('orange'));
    yline(ax,-tolerance,'--','Color',local_color('orange'));
    ax.XTick = 1:height(measured);
    ax.XTickLabel = strrep(cellstr(measured.event),'_',' ');
    ax.XTickLabelRotation = 20;
    ylabel(ax,'observed - expected (us)');
    subtitle(ax,'Median persisted timestamp offsets; orange = tolerance');
    local_style_axes(ax);
end
end

function [data,available,reason] = local_extract_ydq(trace)
data = struct('y_A',zeros(0,2),'valid',false(0,1));
available = false;
reason = 'Selected trace lacks y_d/y_q or residual data.';
if ~isstruct(trace), return; end
if isfield(trace,'y_A')
    y = double(trace.y_A);
elseif isfield(trace,'residual_A') && isfield(trace,'direction_sign')
    residual = double(trace.residual_A);
    direction = double(trace.direction_sign(:));
    n = min(size(residual,1),numel(direction));
    y = residual(1:n,:).*direction(1:n);
else
    return;
end
if size(y,2) ~= 2, return; end
valid = local_trace_mask(trace,size(y,1));
finite = all(isfinite(y),2);
mask = valid & finite;
if ~any(mask)
    reason = 'Selected trace has no finite accepted y_d/y_q samples.';
    return;
end
indices = local_even_indices(find(mask),2000);
data.y_A = y(indices,:);
data.valid = true(numel(indices),1);
available = true;
reason = '';
end

function fig = local_plot_ydq(data,caseId)
fig = local_new_figure();
ax = axes(fig);
y = data.y_A;
plot(ax,y(:,2),y(:,1),'-','Color',local_color('gray'), ...
    'LineWidth',0.7); hold(ax,'on');
plot(ax,y(:,2),y(:,1),'o','Color',local_color('blue'), ...
    'MarkerFaceColor','w','MarkerSize',3,'LineWidth',0.7);
xline(ax,0,':','Color',local_color('ink'));
yline(ax,0,':','Color',local_color('ink'));
axis(ax,'equal');
xlabel(ax,'y_q (A)'); ylabel(ax,'y_d (A)');
title(ax,'Direction-normalized residual trajectory');
subtitle(ax,sprintf('%s; %d accepted samples', ...
    strrep(char(caseId),'_',' '),size(y,1)));
local_style_axes(ax);
end

function [data,available,reason] = local_collect_residual_speed(inventory,cfg)
data = struct('speed_e_radps',zeros(0,1),'amplitude_A',zeros(0,1), ...
    'expected_A',zeros(0,1),'case_count',0);
reason = 'No readable trace contained accepted speed/residual samples.';
for k = 1:numel(inventory)
    if ~inventory(k).trace_available, continue; end
    [trace,ok] = local_load_trace(char(inventory(k).trace_path));
    if ~ok, continue; end
    speed = local_trace_speed(trace);
    amplitude = local_trace_amplitude(trace);
    n = min(numel(speed),numel(amplitude));
    if n == 0, continue; end
    speed = abs(speed(1:n));
    amplitude = amplitude(1:n);
    mask = local_trace_mask(trace,n) & isfinite(speed) & isfinite(amplitude);
    if ~any(mask), continue; end
    indices = local_even_indices(find(mask),500);
    speed = speed(indices);
    amplitude = amplitude(indices);
    expected = local_trace_expected(trace,n);
    if isempty(expected)
        expected = local_expected_amplitude(speed,cfg);
    else
        expected = expected(indices);
    end
    data.speed_e_radps = [data.speed_e_radps;speed];
    data.amplitude_A = [data.amplitude_A;amplitude];
    data.expected_A = [data.expected_A;expected];
    data.case_count = data.case_count + 1;
end
available = ~isempty(data.speed_e_radps);
if available, reason = ''; end
end

function fig = local_plot_residual_speed(data,cfg)
fig = local_new_figure();
ax = axes(fig);
scatter(ax,data.speed_e_radps,data.amplitude_A,10, ...
    'MarkerEdgeColor',local_color('blue'),'MarkerFaceColor','none');
hold(ax,'on');
scatter(ax,data.speed_e_radps,data.expected_A,8,'x', ...
    'MarkerEdgeColor',local_color('orange'));
xmax = max(data.speed_e_radps);
xlineValues = linspace(0,max(xmax,1),200).';
plot(ax,xlineValues,local_expected_amplitude(xlineValues,cfg), ...
    '--','Color',local_color('gray'),'LineWidth',1.3);
xlabel(ax,'|estimated electrical speed| (rad/s)');
ylabel(ax,'residual amplitude (A)');
title(ax,'Residual amplitude versus available speed');
subtitle(ax,sprintf('%d sampled records from %d cases; E07 values are persisted per case', ...
    numel(data.speed_e_radps),data.case_count));
legend(ax,{'observed accepted samples','persisted E07 expected amplitude', ...
    'nominal-config E07 line'}, ...
    'Location','northwest');
local_style_axes(ax);
end

function speed = local_trace_speed(trace)
if isfield(trace,'omega_e_est_radps')
    speed = double(trace.omega_e_est_radps(:));
elseif isfield(trace,'IdentificationBus') && ...
        isfield(trace.IdentificationBus,'omega_e_radps')
    speed = double(trace.IdentificationBus.omega_e_radps(:));
else
    speed = zeros(0,1);
end
end

function amplitude = local_trace_amplitude(trace)
if isfield(trace,'residual_amplitude_A')
    amplitude = double(trace.residual_amplitude_A(:));
elseif isfield(trace,'y_A') && size(trace.y_A,2) == 2
    amplitude = hypot(double(trace.y_A(:,1)),double(trace.y_A(:,2)));
elseif isfield(trace,'residual_A') && size(trace.residual_A,2) == 2
    amplitude = hypot(double(trace.residual_A(:,1)), ...
        double(trace.residual_A(:,2)));
else
    amplitude = zeros(0,1);
end
end

function expected = local_trace_expected(trace,n)
if isfield(trace,'expected_amplitude_A') && ...
        numel(trace.expected_amplitude_A) >= n
    expected = double(trace.expected_amplitude_A(1:n));
    expected = expected(:);
else
    expected = zeros(0,1);
end
end

function expected = local_expected_amplitude(speed,cfg)
Ts = local_cfg_number(cfg,{'timing','T_ident_s'},50e-6);
psi = local_cfg_number(cfg,{'motor','psi_f_Wb'},0.004208);
Ls = local_cfg_number(cfg,{'motor','Ls_H'},61e-6);
expected = Ts*psi.*abs(double(speed))/Ls;
end

function [data,available,reason] = local_condition_consistency(metrics)
data = table();
available = false;
reason = 'Speed-direction and load metrics are unavailable.';
if isempty(metrics), return; end
group = string(metrics.group);
mask = ismember(group,["speed_direction","load"]);
mask = mask & isfinite(metrics.rmse_e_deg) & ...
    isfinite(metrics.mean_estimation_error_e_deg);
data = metrics(mask,{'case_id','group','rmse_e_deg', ...
    'mean_estimation_error_e_deg','valid_fraction'});
available = ~isempty(data);
if available, reason = ''; end
end

function fig = local_plot_condition_consistency(data)
fig = local_new_figure();
layout = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
title(layout,'Condition consistency','FontWeight','bold');
x = 1:height(data);
labels = strrep(cellstr(data.case_id),'_',' ');

ax = nexttile(layout);
plot(ax,x,data.mean_estimation_error_e_deg,'o-', ...
    'Color',local_color('blue'),'MarkerFaceColor','w','LineWidth',1.1);
yline(ax,0,'-','Color',local_color('ink'));
ylabel(ax,'mean bias (deg_e)');
ax.XTick = x; ax.XTickLabel = labels; ax.XTickLabelRotation = 25;
subtitle(ax,'Signed circular estimation bias');
local_style_axes(ax);

ax = nexttile(layout);
bar(ax,x,data.rmse_e_deg,0.65,'FaceColor',local_color('orange'), ...
    'EdgeColor',local_color('ink'));
ylabel(ax,'RMSE (deg_e)');
ax.XTick = x; ax.XTickLabel = labels; ax.XTickLabelRotation = 25;
subtitle(ax,'Same persisted deployment estimator across speed, direction, and load');
local_style_axes(ax);
end

function [budget,meta] = local_error_budget(metrics)
names = {'component','case_id','category','observed_rmse_e_deg', ...
    'reference_rmse_e_deg','incremental_rss_e_deg','mean_bias_e_deg', ...
    'valid_fraction','available','note'};
if isempty(metrics)
    budget = table("unavailable","","unavailable",NaN,NaN,NaN,NaN,NaN, ...
        false,"No metrics.csv or per-case metrics were readable.", ...
        'VariableNames',names);
    meta = struct('available',false,'reference_case_id',"", ...
        'reference_rmse_e_deg',NaN,'reason','Metrics are unavailable.');
    return;
end

referenceIndex = find(metrics.case_id=="periodic_combined" & ...
    isfinite(metrics.rmse_e_deg),1);
if isempty(referenceIndex)
    referenceIndex = find(metrics.case_id=="fixed_00deg_e" & ...
        isfinite(metrics.rmse_e_deg),1);
end
if isempty(referenceIndex)
    referenceIndex = find(isfinite(metrics.rmse_e_deg),1);
end
if isempty(referenceIndex)
    budget = table("unavailable","","unavailable",NaN,NaN,NaN,NaN,NaN, ...
        false,"No finite RMSE metric was found.",'VariableNames',names);
    meta = struct('available',false,'reference_case_id',"", ...
        'reference_rmse_e_deg',NaN,'reason','No finite RMSE metric was found.');
    return;
end

referenceCase = metrics.case_id(referenceIndex);
referenceRmse = metrics.rmse_e_deg(referenceIndex);
selected = ismember(string(metrics.group), ...
    ["parameter_mismatch","angle_sampling","nonideal","voltage_ab"]);
selected(referenceIndex) = true;
indices = find(selected & isfinite(metrics.rmse_e_deg));
n = numel(indices);
component = strings(n,1); case_id = strings(n,1); category = strings(n,1);
observed = NaN(n,1); baseline = referenceRmse*ones(n,1);
incremental = NaN(n,1); bias = NaN(n,1); validFraction = NaN(n,1);
available = true(n,1); note = strings(n,1);
for k = 1:n
    index = indices(k);
    case_id(k) = metrics.case_id(index);
    component(k) = metrics.case_id(index);
    category(k) = metrics.group(index);
    if index == referenceIndex, category(k) = "ideal_reference"; end
    observed(k) = metrics.rmse_e_deg(index);
    incremental(k) = sqrt(max(observed(k)^2-referenceRmse^2,0));
    bias(k) = metrics.mean_estimation_error_e_deg(index);
    validFraction(k) = metrics.valid_fraction(index);
    note(k) = "Increment is root-sum-square excess over the selected reference; descriptive only.";
end
budget = table(component,case_id,category,observed,baseline,incremental, ...
    bias,validFraction,available,note,'VariableNames',names);
meta.available = ~isempty(budget);
meta.reference_case_id = referenceCase;
meta.reference_rmse_e_deg = referenceRmse;
meta.reason = '';
end

function [ref,metadata,refTable] = local_reference_lut(trace,caseId,cfg)
M = round(local_cfg_number(cfg,{'stage1','reference_lut_nodes'},128));
M = max(2,M);
phi = zeros(0,1); delta = zeros(0,1); valid = false(0,1);
reason = 'Reference LUT inputs are unavailable.';
if isstruct(trace)
    if isfield(trace,'IdentificationBus') && ...
            isfield(trace.IdentificationBus,'theta_m_raw_rad')
        phi = double(trace.IdentificationBus.theta_m_raw_rad(:));
    elseif isfield(trace,'theta_m_raw_rad')
        phi = double(trace.theta_m_raw_rad(:));
    end
    if isfield(trace,'truth_error_e_rad')
        delta = double(trace.truth_error_e_rad(:));
    elseif isfield(trace,'IdentificationBus') && ...
            isfield(trace.IdentificationBus,'theta_e_rad') && ...
            isfield(trace,'EvaluationTruthBus') && ...
            isfield(trace.EvaluationTruthBus,'theta_e_true_rad')
        raw = double(trace.IdentificationBus.theta_e_rad(:));
        truth = double(trace.EvaluationTruthBus.theta_e_true_rad(:));
        n = min(numel(raw),numel(truth));
        delta = anglelut.wrap_to_pi(raw(1:n)-truth(1:n));
    end
    n = min(numel(phi),numel(delta));
    if n > 0
        valid = local_trace_mask(trace,n);
        phi = phi(1:n); delta = delta(1:n);
        valid = valid & isfinite(phi) & isfinite(delta);
        reason = '';
    end
end

% Required evaluation-only aggregation call.  Empty input produces an
% explicit uncovered LUT for partial runs rather than a fabricated table.
ref = anglelut.aggregate_reference_lut(phi,delta,M,valid);
metadata = struct();
metadata.schema_version = 'stage1-reference-lut-report-v1';
metadata.available = ref.accepted_samples > 0 && any(ref.valid_mask);
metadata.reason = reason;
if ~metadata.available && isempty(reason)
    metadata.reason = 'No valid evaluation samples reached a LUT node.';
end
metadata.source_case_id = char(caseId);
metadata.evaluation_only = true;
metadata.feedback_used = false;
metadata.index_signal = 'raw mechanical angle';
metadata.value_signal = 'truth electrical error';
metadata.node_count = M;
metadata.accepted_samples = double(ref.accepted_samples);
metadata.coverage_fraction = ref.coverage_fraction;

polePairs = local_cfg_number(cfg,{'motor','pole_pairs'},21);
node_index = (0:M-1).';
phi_m_rad = ref.node_phi_m_rad;
phi_m_deg = rad2deg(phi_m_rad);
lut_e_rad = ref.lut_e_rad;
lut_e_deg = rad2deg(lut_e_rad);
lut_m_rad = lut_e_rad/polePairs;
lut_m_deg = rad2deg(lut_m_rad);
valid_mask = ref.valid_mask;
weight_sum = ref.weight_sum;
sample_hits = double(ref.sample_hits);
refTable = table(node_index,phi_m_rad,phi_m_deg,lut_e_rad,lut_e_deg, ...
    lut_m_rad,lut_m_deg,valid_mask,weight_sum,sample_hits);
end

function fig = local_plot_reference_lut(ref,metadata)
fig = local_new_figure();
layout = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
title(layout,'Evaluation-only reference LUT','FontWeight','bold');
valid = logical(ref.valid_mask);

ax = nexttile(layout);
plot(ax,rad2deg(ref.node_phi_m_rad(valid)), ...
    rad2deg(ref.lut_e_rad(valid)),'o-', ...
    'Color',local_color('blue'),'MarkerFaceColor','w','LineWidth',1.1);
xlabel(ax,'raw mechanical angle (deg_m)');
ylabel(ax,'reference error (deg_e)');
subtitle(ax,sprintf('%s; coverage %.1f%%; evaluation only', ...
    strrep(metadata.source_case_id,'_',' '),100*ref.coverage_fraction));
local_style_axes(ax);

ax = nexttile(layout);
bar(ax,rad2deg(ref.node_phi_m_rad),ref.weight_sum,1, ...
    'FaceColor',local_color('orange'),'EdgeColor','none');
xlabel(ax,'raw mechanical angle (deg_m)');
ylabel(ax,'aggregation weight');
subtitle(ax,'Uncovered nodes remain invalid and are never filled by regularization');
local_style_axes(ax);
end

function [gateReport,text] = local_gate_failures(gate,available,reason)
failureTemplate = struct('path','', 'value',false, 'message','');
failures = repmat(failureTemplate,0,1);
status = 'UNKNOWN';
if available
    if isfield(gate,'status'), status = char(string(gate.status)); end
    if isfield(gate,'checks')
        failures = local_collect_false_checks(gate.checks,'checks',failures);
    end
    if isfield(gate,'critical_early_stop') && ...
            isstruct(gate.critical_early_stop) && ...
            isfield(gate.critical_early_stop,'checks')
        failures = local_collect_false_checks( ...
            gate.critical_early_stop.checks, ...
            'critical_early_stop.checks',failures);
    end
end
gateReport = struct('schema_version','stage1-gate-failures-v1', ...
    'available',available, 'reason',reason, 'gate_status',status, ...
    'failure_count',numel(failures), 'failures',failures, ...
    'gate_modified',false);

lines = ["Stage 1 gate failure report"; ...
    "Gate status: "+string(status); ...
    "Gate file available: "+string(available); ...
    "Failure count: "+string(numel(failures))];
if ~available
    lines(end+1,1) = "Reason: "+string(reason);
elseif isempty(failures)
    lines(end+1,1) = "No false gate checks were recorded.";
else
    for k = 1:numel(failures)
        lines(end+1,1) = "- "+string(failures(k).path); %#ok<AGROW>
    end
end
lines(end+1,1) = "This report is read-only and did not modify gate.json.";
text = strjoin(lines,newline);
end

function failures = local_collect_false_checks(value,prefix,failures)
if ~isstruct(value), return; end
names = fieldnames(value);
for k = 1:numel(names)
    field = names{k};
    child = value.(field);
    path = [prefix '.' field];
    if isstruct(child)
        failures = local_collect_false_checks(child,path,failures);
    elseif islogical(child) && isscalar(child) && ~child
        item = struct('path',path,'value',false, ...
            'message','Persisted gate check is false.');
        failures(end+1,1) = item; %#ok<AGROW>
    end
end
end

function [available,reason] = local_export_plot(plotter,reportDir,stem, ...
    requestedAvailable,requestedReason)
available = logical(requestedAvailable);
reason = char(string(requestedReason));
fig = [];
try
    if available
        fig = plotter();
    else
        fig = local_placeholder_figure(stem,reason);
    end
    local_export_figure(fig,reportDir,stem);
catch ME
    if ~isempty(fig) && isgraphics(fig), close(fig); end
    available = false;
    reason = local_join_reason(reason, ...
        sprintf('Plot generation failed: %s',ME.message));
    fig = local_placeholder_figure(stem,reason);
    local_export_figure(fig,reportDir,stem);
end
if ~isempty(fig) && isgraphics(fig), close(fig); end
end

function local_export_figure(fig,reportDir,stem)
exportgraphics(fig,fullfile(reportDir,[stem '.png']),'Resolution',150);
exportgraphics(fig,fullfile(reportDir,[stem '.pdf']),'ContentType','vector');
end

function fig = local_new_figure()
fig = figure('Visible','off','Color','w','Position',[100 100 1100 700]);
end

function fig = local_placeholder_figure(stem,reason)
fig = local_new_figure();
ax = axes(fig,'Position',[0.08 0.10 0.84 0.82]);
axis(ax,'off');
text(ax,0.5,0.62,strrep(stem,'_',' '),'HorizontalAlignment','center', ...
    'FontName','Arial','FontSize',18,'FontWeight','bold', ...
    'Color',local_color('ink'));
text(ax,0.5,0.47,'Unavailable for this partial run', ...
    'HorizontalAlignment','center','FontName','Arial','FontSize',13, ...
    'Color',local_color('orange'));
text(ax,0.5,0.36,char(string(reason)),'HorizontalAlignment','center', ...
    'FontName','Arial','FontSize',10,'Color',local_color('gray'), ...
    'Interpreter','none');
end

function local_style_axes(ax)
ax.FontName = 'Arial';
ax.FontSize = 10;
ax.LineWidth = 0.8;
ax.XColor = local_color('ink');
ax.YColor = local_color('ink');
ax.GridColor = [0.85 0.87 0.89];
ax.GridAlpha = 0.65;
ax.Box = 'off';
grid(ax,'on');
end

function local_axes_message(ax,message)
axis(ax,'off');
text(ax,0.5,0.5,message,'HorizontalAlignment','center', ...
    'FontName','Arial','FontSize',11,'Color',local_color('gray'), ...
    'Interpreter','none');
end

function color = local_color(name)
switch char(name)
    case 'blue'
        color = [0.12 0.36 0.62];
    case 'orange'
        color = [0.88 0.43 0.12];
    case 'gray'
        color = [0.45 0.49 0.53];
    otherwise
        color = [0.16 0.18 0.20];
end
end

function mask = local_trace_mask(trace,n)
mask = true(n,1);
if isfield(trace,'valid')
    raw = double(trace.valid(:));
    value = isfinite(raw) & raw ~= 0;
    count = min(n,numel(value));
    mask = false(n,1);
    mask(1:count) = value(1:count);
end
if isfield(trace,'evaluation_mask')
    raw = double(trace.evaluation_mask(:));
    value = isfinite(raw) & raw ~= 0;
    count = min(n,numel(value));
    evaluation = false(n,1);
    evaluation(1:count) = value(1:count);
    mask = mask & evaluation;
end
end

function indices = local_even_indices(indices,maximumCount)
indices = indices(:);
if numel(indices) <= maximumCount, return; end
positions = unique(round(linspace(1,numel(indices),maximumCount))).';
indices = indices(positions);
end

function column = local_struct_column(value,field)
if isstruct(value) && isfield(value,field)
    column = double(value.(field)(:));
else
    column = zeros(0,1);
end
end

function value = local_finite_median(values)
values = double(values(:));
values = values(isfinite(values));
if isempty(values), value = NaN; else, value = median(values); end
end

function value = local_cfg_number(cfg,path,defaultValue)
value = cfg;
for k = 1:numel(path)
    field = path{k};
    if ~isstruct(value) || ~isfield(value,field)
        value = defaultValue;
        return;
    end
    value = value.(field);
end
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    value = defaultValue;
else
    value = double(value);
end
end

function value = local_struct_number(s,field,defaultValue)
if isstruct(s) && isfield(s,field) && isnumeric(s.(field)) && ...
        isscalar(s.(field)) && isfinite(s.(field))
    value = double(s.(field));
else
    value = defaultValue;
end
end

function [value,available,reason] = local_read_json(path)
value = struct();
available = false;
reason = sprintf('Missing JSON file: %s',path);
if ~isfile(path), return; end
try
    value = jsondecode(fileread(path));
    available = true;
    reason = '';
catch ME
    reason = sprintf('Unreadable JSON file %s: %s',path,ME.message);
end
end

function artifact = local_artifact(name,available,reason,caseId,files)
artifact = local_artifact_template();
artifact.name = char(string(name));
artifact.available = logical(available);
artifact.reason = char(string(reason));
artifact.source_case_id = char(string(caseId));
artifact.files = string(files(:)).';
end

function artifact = local_artifact_template()
artifact = struct('name','', 'available',false, 'reason','', ...
    'source_case_id','', 'files',strings(1,0));
end

function reason = local_join_reason(first,second)
first = strtrim(char(string(first)));
second = strtrim(char(string(second)));
if isempty(first)
    reason = second;
elseif isempty(second)
    reason = first;
else
    reason = [first ' ' second];
end
end

function local_write_text(path,text)
fid = fopen(path,'w','n','UTF-8');
if fid < 0
    error('anglelut:IO','Cannot open %s for writing.',path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',char(string(text)));
end
