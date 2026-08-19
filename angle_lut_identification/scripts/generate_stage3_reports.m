function manifest = generate_stage3_reports(stageDir)
%GENERATE_STAGE3_REPORTS Create the auditable Scheme-5 report bundle.

arguments
    stageDir (1,:) char
end
assert(isfolder(stageDir),'anglelut:Stage3ReportDirectory', ...
    'Stage-3 result directory does not exist.');
reportDir = fullfile(stageDir,'reports');
if ~isfolder(reportDir), mkdir(reportDir); end
gatePath = fullfile(stageDir,'gate.json');
if isfile(gatePath), gateBefore = file_sha256(gatePath); else, gateBefore = ''; end
context = local_context(stageDir);
spec = [ ...
    struct('name','lut_truth_shadow_active','title','LUT truth / shadow / active'), ...
    struct('name','lut_learning_evolution','title','LUT learning evolution'), ...
    struct('name','scheme4_scheme5_comparison','title','Scheme 4 / Scheme 5 comparison'), ...
    struct('name','amplitude_mode_comparison','title','Amplitude-mode comparison'), ...
    struct('name','tangent_radial_diagnostics','title','Tangential / radial diagnostics'), ...
    struct('name','coverage_fusion_events','title','Coverage and fusion events'), ...
    struct('name','active_off_on_pairs','title','Frozen active-off / active-on pairs'), ...
    struct('name','direction_speed_load_drift','title','Direction / speed / load drift'), ...
    struct('name','parameter_sensitivity','title','Parameter and implementation sensitivity'), ...
    struct('name','safety_compute_storage','title','Safety, compute, and storage')];
reports = repmat(struct('name','','png','','pdf','','available',false),numel(spec),1);
for k = 1:numel(spec)
    fig = figure('Visible','off','Color','w','Position',[100 100 1100 650]);
    available = local_draw(fig,spec(k).name,spec(k).title,context);
    pngPath = fullfile(reportDir,[spec(k).name '.png']);
    pdfPath = fullfile(reportDir,[spec(k).name '.pdf']);
    exportgraphics(fig,pngPath,'Resolution',150);
    exportgraphics(fig,pdfPath,'ContentType','vector');
    if strcmp(spec(k).name,'lut_learning_evolution')
        local_write_evolution_gif(context,fig,fullfile(reportDir, ...
            'lut_learning_evolution.gif'));
    end
    close(fig);
    reports(k) = struct('name',spec(k).name,'png',pngPath, ...
        'pdf',pdfPath,'available',logical(available));
end

local_write_tables(reportDir,context);
gateAfter = gateBefore;
if isfile(gatePath), gateAfter = file_sha256(gatePath); end
manifest = struct('schema_version','stage3-report-bundle-v1', ...
    'generated_at_utc',local_iso_time(),'stage3_directory',stageDir, ...
    'reports',reports,'primary_profile_id','periodic_combined', ...
    'truth_feedback_used',false,'joint_parameter_identification_used',false, ...
    'stage4_executed',false,'gate_sha256_before',gateBefore, ...
    'gate_sha256_after',gateAfter,'gate_unchanged',strcmpi(gateBefore,gateAfter));
write_json_file(fullfile(reportDir,'report_manifest.json'),manifest);
end

function context = local_context(stageDir)
context.stage_dir = stageDir;
context.metrics = table();
metricsPath = fullfile(stageDir,'metrics.csv');
if isfile(metricsPath), context.metrics = readtable(metricsPath,'TextType','string'); end
context.result = struct();
resultPath = fullfile(stageDir,'result.json');
if isfile(resultPath), context.result = jsondecode(fileread(resultPath)); end
context.primary_path = fullfile(stageDir,'training','periodic_combined', ...
    'M64','nominal_model','scheme5_state.mat');
context.primary = struct();
if isfile(context.primary_path), context.primary = load(context.primary_path); end
context.scheme4 = struct();
if isfield(context.result,'prerequisite_stage2') && ...
        isfield(context.result.prerequisite_stage2,'path')
    path = fullfile(context.result.prerequisite_stage2.path,'training', ...
        'periodic_combined','M64','scheme4_state.mat');
    if isfile(path), context.scheme4 = load(path,'state'); end
end
end

function available = local_draw(fig,name,titleText,c)
available = false;
switch name
    case 'lut_truth_shadow_active'
        available = local_lut_plot(fig,titleText,c);
    case 'lut_learning_evolution'
        available = local_evolution_plot(fig,titleText,c);
    case 'scheme4_scheme5_comparison'
        available = local_scheme_compare(fig,titleText,c);
    case 'amplitude_mode_comparison'
        available = local_mode_plot(fig,titleText,c);
    case 'tangent_radial_diagnostics'
        available = local_tangent_plot(fig,titleText,c);
    case 'coverage_fusion_events'
        available = local_coverage_plot(fig,titleText,c);
    case 'active_off_on_pairs'
        available = local_pair_plot(fig,titleText,c);
    case 'direction_speed_load_drift'
        available = local_drift_plot(fig,titleText,c);
    case 'parameter_sensitivity'
        available = local_sensitivity_plot(fig,titleText,c);
    otherwise
        available = local_cost_plot(fig,titleText,c);
end
if ~available, local_placeholder(fig,titleText); end
end

function ok = local_lut_plot(fig,titleText,c)
ok = local_has_primary(c); if ~ok, return; end
s = c.primary.state; r = c.primary.reference; M = double(s.M);
x = (0:M-1).'*360/M;
ax = axes(fig); hold(ax,'on'); grid(ax,'on');
plot(ax,x,rad2deg(r.lut_e_rad),'k','LineWidth',2,'DisplayName','truth (evaluation only)');
plot(ax,x,rad2deg(s.shadow_lut_e_rad),'Color',[0.1 0.45 0.85], ...
    'LineWidth',1.6,'DisplayName','Scheme 5 shadow');
plot(ax,x,rad2deg(s.active_lut_e_rad),'Color',[0.85 0.25 0.1], ...
    'LineWidth',1.6,'DisplayName','Scheme 5 active');
plot(ax,x,zeros(M,1),'--','Color',[0.5 0.5 0.5], ...
    'DisplayName','zero LUT (uncompensated)');
xlabel(ax,'Raw mechanical angle (deg_m)'); ylabel(ax,'Electrical correction (deg_e)');
title(ax,titleText); legend(ax,'Location','best'); xlim(ax,[0 360]);
end

function ok = local_evolution_plot(fig,titleText,c)
ok = local_has_history(c); if ~ok, return; end
h = c.primary.history; r = c.primary.reference.lut_e_rad(:).';
count = size(h.active_lut_e_rad,1); idx = (1:count).';
shadow = zeros(count,1); active = shadow; baseline = sqrt(mean(r.^2));
for k = 1:count
    shadow(k) = local_circular_rms(h.shadow_lut_e_rad(k,:)-r);
    active(k) = local_circular_rms(h.active_lut_e_rad(k,:)-r);
end
t = tiledlayout(fig,1,2,'TileSpacing','compact');
ax = nexttile(t); hold(ax,'on'); grid(ax,'on');
plot(ax,idx,rad2deg(shadow),'-o','DisplayName','shadow RMSE');
plot(ax,idx,rad2deg(active),'-s','DisplayName','active RMSE');
plot(ax,idx,rad2deg(baseline)*ones(count,1),'--k','DisplayName','zero-LUT RMSE');
xlabel(ax,'Fusion event'); ylabel(ax,'LUT RMSE (deg_e)'); legend(ax,'Location','best');
ax = nexttile(t); hold(ax,'on'); grid(ax,'on');
improvement = 100*(1-active/max(baseline,eps));
plot(ax,idx,improvement,'-o','Color',[0.15 0.6 0.25]);
yline(ax,80,'--','80% gate'); xlabel(ax,'Fusion event');
ylabel(ax,'Improvement from zero LUT (%)');
title(t,titleText + " — improvement should rise and then settle");
end

function ok = local_scheme_compare(fig,titleText,c)
ok = local_has_primary(c) && isfield(c.scheme4,'state'); if ~ok, return; end
a = c.primary.state; b = c.scheme4.state; M = double(a.M); x=(0:M-1).'*360/M;
t=tiledlayout(fig,1,2,'TileSpacing','compact');
ax=nexttile(t); hold(ax,'on'); grid(ax,'on');
plot(ax,x,rad2deg(b.shadow_lut_e_rad),'--','LineWidth',1.5,'DisplayName','Scheme 4 shadow');
plot(ax,x,rad2deg(a.shadow_lut_e_rad),'-','LineWidth',1.5,'DisplayName','Scheme 5 shadow');
legend(ax,'Location','best'); xlabel(ax,'deg_m'); ylabel(ax,'deg_e');
ax=nexttile(t); hold(ax,'on'); grid(ax,'on');
plot(ax,x,rad2deg(b.active_lut_e_rad),'--','LineWidth',1.5,'DisplayName','Scheme 4 active');
plot(ax,x,rad2deg(a.active_lut_e_rad),'-','LineWidth',1.5,'DisplayName','Scheme 5 active');
legend(ax,'Location','best'); xlabel(ax,'deg_m'); ylabel(ax,'deg_e'); title(t,titleText);
end

function ok = local_mode_plot(fig,titleText,c)
T=c.metrics; ok=~isempty(T) && all(ismember({'phase','case_id','amplitude_mode', ...
    'active_rmse_e_deg'},T.Properties.VariableNames)); if ~ok, return; end
mask=T.case_id=="periodic_combined" & contains(T.phase,"M64"); T=T(mask,:);
ok=height(T)>=3; if ~ok, return; end
ax=axes(fig); bar(ax,categorical(T.amplitude_mode),T.active_rmse_e_deg); grid(ax,'on');
ylabel(ax,'Active LUT RMSE (deg_e)'); title(ax,titleText + " (nominal is gate-driving)");
end

function ok = local_tangent_plot(fig,titleText,c)
ok=local_has_history(c); if ~ok, return; end
h=c.primary.history; mask=h.accepted & isfinite(h.tangent_residual) & isfinite(h.radial_residual);
i=find(mask); if isempty(i), ok=false; return; end
stride=max(1,floor(numel(i)/6000)); i=i(1:stride:end);
t=tiledlayout(fig,2,1,'TileSpacing','compact');
ax=nexttile(t); plot(ax,i,h.tangent_residual(i),'Color',[0.1 0.45 0.85]); grid(ax,'on');
ylabel(ax,'t (A)'); ax=nexttile(t); plot(ax,i,h.radial_residual(i),'Color',[0.85 0.3 0.15]);
grid(ax,'on'); ylabel(ax,'n (A)'); xlabel(ax,'Accepted sample index'); title(t,titleText);
end

function ok = local_coverage_plot(fig,titleText,c)
ok=local_has_history(c); if ~ok, return; end
h=c.primary.history; n=numel(h.fusion_count); if n==0, ok=false; return; end
t=tiledlayout(fig,1,2,'TileSpacing','compact');
ax=nexttile(t); plot(ax,h.fusion_count,h.fusion_coverage_fraction,'-o'); grid(ax,'on');
ylim(ax,[0 1.05]); xlabel(ax,'Fusion event'); ylabel(ax,'Coverage fraction');
ax=nexttile(t); plot(ax,h.fusion_count,rad2deg(h.active_update_rms_e_rad),'-s'); grid(ax,'on');
xlabel(ax,'Fusion event'); ylabel(ax,'Active update RMS (deg_e)'); yline(ax,0.25,'--','gate');
title(t,titleText);
end

function ok = local_pair_plot(fig,titleText,c)
T=c.metrics; ok=~isempty(T) && all(ismember({'phase','case_id', ...
    'control_angle_improvement'},T.Properties.VariableNames)); if ~ok, return; end
T=T(T.phase=="FROZEN_PAIR",:); ok=~isempty(T); if ~ok, return; end
ax=axes(fig); bar(ax,100*T.control_angle_improvement); grid(ax,'on');
yline(ax,60,'--','ideal percentage branch'); yline(ax,50,':','nonideal gate');
xticks(ax,1:height(T)); xticklabels(ax,T.case_id); xtickangle(ax,45);
ylabel(ax,'Control-angle RMSE improvement (%)'); title(ax,titleText);
end

function ok = local_drift_plot(fig,titleText,c)
T=c.metrics; ok=~isempty(T) && all(ismember({'phase','case_id','lut_drift_e_deg'}, ...
    T.Properties.VariableNames)); if ~ok, return; end
T=T(T.phase=="CONDITION_DRIFT",:); ok=~isempty(T); if ~ok, return; end
ax=axes(fig); bar(ax,T.lut_drift_e_deg); grid(ax,'on'); yline(ax,0.5,'--','gate');
xticks(ax,1:height(T)); xticklabels(ax,T.case_id); xtickangle(ax,35);
ylabel(ax,'Circular LUT drift (deg_e)'); title(ax,titleText);
end

function ok = local_sensitivity_plot(fig,titleText,c)
T=c.metrics; ok=~isempty(T) && all(ismember({'phase','case_id','tangent_rms', ...
    'radial_rms'},T.Properties.VariableNames)); if ~ok, return; end
T=T(T.phase=="SENSITIVITY",:); ok=~isempty(T); if ~ok, return; end
ax=axes(fig); bar(ax,[T.tangent_rms,T.radial_rms]); grid(ax,'on');
xticks(ax,1:height(T)); xticklabels(ax,T.case_id); xtickangle(ax,35);
ylabel(ax,'Residual diagnostic RMS'); legend(ax,{'tangent','radial'},'Location','best');
title(ax,titleText + " (diagnostic, not exclusive attribution)");
end

function ok = local_cost_plot(fig,titleText,c)
ok=local_has_primary(c); if ~ok, return; end
s=c.primary.state; values=[double(s.M),512,double(s.sample_count), ...
    double(s.fusion_count),rad2deg(max(abs(s.active_lut_e_rad)))];
ax=axes(fig); bar(ax,values); grid(ax,'on');
xticks(ax,1:5); xticklabels(ax,{'state nodes','runtime nodes','samples', ...
    'fusion events','max active deg_e'}); xtickangle(ax,25); title(ax,titleText);
end

function local_placeholder(fig,titleText)
ax=axes(fig); axis(ax,[0 1 0 1]); axis(ax,'off');
text(ax,0.5,0.56,titleText,'HorizontalAlignment','center', ...
    'FontSize',16,'FontWeight','bold');
text(ax,0.5,0.44,'Unavailable in this partial run', ...
    'HorizontalAlignment','center','FontSize',12,'Color',[0.4 0.4 0.4]);
end

function local_write_evolution_gif(c,fig,path)
if local_has_history(c) && size(c.primary.history.active_lut_e_rad,1)>0
    h=c.primary.history; r=c.primary.reference.lut_e_rad(:); M=numel(r); x=(0:M-1).'*360/M;
    frameFig=figure('Visible','off','Color','w','Position',[100 100 900 550]);
    count=size(h.active_lut_e_rad,1); indices=unique(round(linspace(1,count,min(count,30))));
    for q=1:numel(indices)
        k=indices(q); clf(frameFig); ax=axes(frameFig); hold(ax,'on'); grid(ax,'on');
        plot(ax,x,rad2deg(r),'k','LineWidth',2,'DisplayName','truth');
        plot(ax,x,rad2deg(h.shadow_lut_e_rad(k,:)),'Color',[0.1 0.45 0.85], ...
            'LineWidth',1.5,'DisplayName','shadow');
        plot(ax,x,rad2deg(h.active_lut_e_rad(k,:)),'Color',[0.85 0.25 0.1], ...
            'LineWidth',1.5,'DisplayName','active');
        xlabel(ax,'Raw mechanical angle (deg_m)'); ylabel(ax,'Correction (deg_e)');
        title(ax,sprintf('Scheme 5 learning — fusion %d of %d',k,count));
        legend(ax,'Location','best'); xlim(ax,[0 360]); local_append_frame(frameFig,path,q==1);
    end
    close(frameFig);
else
    local_append_frame(fig,path,true);
end
end

function local_append_frame(fig,path,isFirst)
temporary=[tempname '.png']; exportgraphics(fig,temporary,'Resolution',100);
cleanup=onCleanup(@()delete(temporary)); [image,map]=rgb2ind(imread(temporary),256);
if isFirst
    imwrite(image,map,path,'gif','LoopCount',inf,'DelayTime',0.25);
else
    imwrite(image,map,path,'gif','WriteMode','append','DelayTime',0.25);
end
clear cleanup;
end

function local_write_tables(reportDir,c)
T=c.metrics;
if isempty(T)
    T=table("unavailable",false,'VariableNames',{'item','available'});
end
writetable(T,fullfile(reportDir,'stage3_report_metrics.csv'));
if local_has_history(c)
    h=c.primary.history; count=size(h.active_lut_e_rad,1);
    reference=c.primary.reference.lut_e_rad(:).';
    shadow=zeros(count,1); active=shadow; improvement=shadow;
    zero=local_circular_rms(reference);
    for k=1:count
        shadow(k)=local_circular_rms(h.shadow_lut_e_rad(k,:)-reference);
        active(k)=local_circular_rms(h.active_lut_e_rad(k,:)-reference);
        improvement(k)=1-active(k)/max(zero,eps);
    end
    evolution=table(h.fusion_count,h.fusion_time_s,h.fusion_travel_m_rad/(2*pi), ...
        h.fusion_coverage_fraction,rad2deg(shadow),rad2deg(active),improvement, ...
        'VariableNames',{'fusion_event','time_s','mechanical_cycles', ...
        'coverage_fraction','shadow_rmse_e_deg','active_rmse_e_deg', ...
        'improvement_fraction'});
else
    evolution=table(zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1),zeros(0,1),'VariableNames', ...
        {'fusion_event','time_s','mechanical_cycles','coverage_fraction', ...
        'shadow_rmse_e_deg','active_rmse_e_deg','improvement_fraction'});
end
writetable(evolution,fullfile(reportDir,'lut_learning_evolution.csv'));
write_json_file(fullfile(reportDir,'lut_learning_evolution.json'), ...
    struct('schema_version','scheme5-learning-evolution-v1', ...
    'evaluation_only_truth_used_for_scoring',true, ...
    'truth_feedback_used_for_learning',false,'rows',table2struct(evolution)));
cost=struct('scheme5_state_nodes',local_state_nodes(c), ...
    'runtime_nodes',512,'history_inside_algorithm_state',false, ...
    'nodes_updated_per_sample',2,'whole_table_operations_per_sample',0, ...
    'joint_parameter_states',0);
write_json_file(fullfile(reportDir,'compute_storage_cost.json'),cost);
end

function value=local_state_nodes(c)
if local_has_primary(c), value=double(c.primary.state.M); else, value=NaN; end
end
function ok=local_has_primary(c)
ok=isfield(c.primary,'state') && isfield(c.primary,'reference');
end
function ok=local_has_history(c)
ok=local_has_primary(c) && isfield(c.primary,'history') && ...
    isfield(c.primary.history,'active_lut_e_rad');
end
function value=local_circular_rms(x)
x=anglelut.wrap_to_pi(double(x(:))); value=sqrt(mean(x.^2));
end
function value=local_iso_time()
value=char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
