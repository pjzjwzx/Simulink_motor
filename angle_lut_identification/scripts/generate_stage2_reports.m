function manifest = generate_stage2_reports(stage2Dir)
%GENERATE_STAGE2_REPORTS Create the reproducible Stage-2 report bundle.

assert(isfolder(stage2Dir),'anglelut:Stage2ReportPath', ...
    'Stage-2 result directory is missing.');
reportDir = fullfile(stage2Dir,'reports');
if ~isfolder(reportDir), mkdir(reportDir); end
gatePath = fullfile(stage2Dir,'gate.json');
gateHashBefore = local_optional_hash(gatePath);
metricsPath = fullfile(stage2Dir,'metrics.csv');
if isfile(metricsPath), metrics = readtable(metricsPath,'TextType','string'); ...
else, metrics = table(); end

entries = repmat(struct('name','','available',false,'png','','pdf',''),0,1);
entries(end+1) = local_lut_report(stage2Dir,reportDir);
entries(end+1) = local_node_error_report(stage2Dir,reportDir);
entries(end+1) = local_convergence_report(stage2Dir,reportDir);
entries(end+1) = local_information_report(stage2Dir,reportDir);
entries(end+1) = local_solver_report(metrics,reportDir);
entries(end+1) = local_frozen_report(metrics,reportDir);
entries(end+1) = local_drift_report(metrics,reportDir);
entries(end+1) = local_safety_report(stage2Dir,reportDir);
entries(end+1) = local_cost_report(reportDir);

cost = local_cost_table();
writetable(cost,fullfile(reportDir,'compute_storage_cost.csv'));
write_json_file(fullfile(reportDir,'compute_storage_cost.json'), ...
    table2struct(cost));

manifest = struct('schema_version','angle-lut-stage2-reports-v1', ...
    'generated_at_utc',local_iso_time(),'reports',entries, ...
    'evaluation_truth_used_for_scoring_only',true, ...
    'truth_feedback_used',false,'gate_sha256_before',gateHashBefore, ...
    'gate_sha256_after',local_optional_hash(gatePath));
assert(strcmpi(manifest.gate_sha256_before,manifest.gate_sha256_after), ...
    'anglelut:Stage2ReportChangedGate','Report generation changed gate.json.');
write_json_file(fullfile(reportDir,'report_manifest.json'),manifest);
end

function entry = local_lut_report(stage2Dir,reportDir)
entry = local_entry('lut_truth_shadow_active',reportDir);
path = fullfile(stage2Dir,'training','periodic_combined','M64', ...
    'lut_nodes.csv');
fig = local_figure();
if isfile(path)
    t = readtable(path);
    phiDeg = rad2deg([t.phi_m_rad; 2*pi]);
    plot(phiDeg,rad2deg([t.reference_e_rad; t.reference_e_rad(1)]), ...
        'k-','LineWidth',1.8); hold on;
    plot(phiDeg,rad2deg([t.shadow_e_rad; t.shadow_e_rad(1)]), ...
        'Color',[0.1 0.45 0.85],'LineWidth',1.5);
    plot(phiDeg,rad2deg([t.active_e_rad; t.active_e_rad(1)]), ...
        'Color',[0.9 0.35 0.1],'LineWidth',1.5);
    legend('Evaluation reference','Shadow','Active','Location','best');
    xlabel('Raw mechanical angle (deg_m)'); ylabel('Error / compensation (deg_e)');
    title('Primary Stage-2 LUT (truth is evaluation-only)'); grid on;
    entry.available = true;
else
    local_unavailable('Primary periodic-combined M64 LUT is unavailable.');
end
local_export(fig,entry); close(fig);
end

function entry = local_node_error_report(stage2Dir,reportDir)
entry = local_entry('node_error',reportDir);
path = fullfile(stage2Dir,'training','periodic_combined','M64', ...
    'lut_nodes.csv');
fig = local_figure();
if isfile(path)
    t = readtable(path);
    shadow = rad2deg(anglelut.wrap_to_pi(t.shadow_e_rad-t.reference_e_rad));
    active = rad2deg(anglelut.wrap_to_pi(t.active_e_rad-t.reference_e_rad));
    a = stem(t.node,shadow,'Color',[0.1 0.45 0.85],'Marker','none'); hold on;
    b = stem(t.node,active,'Color',[0.9 0.35 0.1],'Marker','none');
    yline(1,'k:'); yline(-1,'k:'); yline(2,'r--'); yline(-2,'r--');
    xlabel('M64 node'); ylabel('Circular node error (deg_e)');
    legend([a,b],{'Shadow','Active'},'Location','best');
    title('Primary LUT node error'); grid on; entry.available = true;
else
    local_unavailable('Primary node-error data is unavailable.');
end
local_export(fig,entry); close(fig);
end

function entry = local_convergence_report(stage2Dir,reportDir)
entry = local_entry('convergence_time_cycles',reportDir);
path = fullfile(stage2Dir,'training','periodic_combined','M64', ...
    'scheme4_state.mat');
fig = local_figure();
if isfile(path)
    loaded = load(path,'history'); h = loaded.history;
    if ~isempty(h.solve_count)
        yyaxis left
        plot(h.travel_m_rad/(2*pi),rad2deg(h.active_update_rms_e_rad), ...
            'o-','LineWidth',1.3,'MarkerSize',3);
        ylabel('Active update RMS (deg_e)');
        yyaxis right
        plot(h.travel_m_rad/(2*pi),h.solve_count,'-','LineWidth',1.2);
        ylabel('Effective solve count'); xlabel('Cumulative mechanical revolutions');
        title('Scheme-4 convergence'); grid on; entry.available = true;
    else
        local_unavailable('No effective solve occurred in this partial run.');
    end
else
    local_unavailable('Primary convergence history is unavailable.');
end
local_export(fig,entry); close(fig);
end

function entry = local_information_report(stage2Dir,reportDir)
entry = local_entry('coverage_information',reportDir);
path = fullfile(stage2Dir,'training','periodic_combined','M64', ...
    'lut_nodes.csv');
fig = local_figure();
if isfile(path)
    t = readtable(path);
    yyaxis left
    bar(t.node,t.node_weight,1,'FaceColor',[0.15 0.55 0.75], ...
        'EdgeColor','none'); ylabel('Cumulative node weight');
    yyaxis right
    plot(t.node,double(t.node_hits),'Color',[0.85 0.3 0.1], ...
        'LineWidth',1.2); ylabel('Node visits'); xlabel('M64 node');
    title(sprintf('Coverage and information (%d/%d valid)', ...
        nnz(t.valid),height(t))); grid on; entry.available = true;
else
    local_unavailable('Primary information data is unavailable.');
end
local_export(fig,entry); close(fig);
end

function entry = local_solver_report(metrics,reportDir)
entry = local_entry('solver_diagnostics',reportDir);
fig = local_figure();
if ~isempty(metrics) && any(startsWith(metrics.phase,"M"))
    rows = startsWith(metrics.phase,"M");
    labels = metrics.phase(rows)+":"+metrics.case_id(rows);
    y = [metrics.solver_relative_difference(rows), ...
        metrics.normal_equation_relative_residual(rows)];
    if size(y,1) == 1
        semilogy(categorical({'Banded vs mldivide', ...
            'Normal-equation residual'}),y(1,:),'o','MarkerSize',7);
        title("Fixed-size solver diagnostics: "+labels(1));
    else
        lines = semilogy(y,'o-','LineWidth',1.1);
        xticks(1:numel(labels)); xticklabels(labels); xtickangle(55);
        legend(lines,{'Banded vs mldivide', ...
            'Normal-equation residual'},'Location','best');
        title('Fixed-size solver diagnostics');
    end
    hold on; yline(1e-9,'r--');
    ylabel('Relative metric');
    grid on;
    entry.available = true;
else
    local_unavailable('Solver diagnostics are unavailable.');
end
local_export(fig,entry); close(fig);
end

function entry = local_frozen_report(metrics,reportDir)
entry = local_entry('active_off_on_pairs',reportDir);
fig = local_figure();
if ~isempty(metrics) && any(metrics.phase == "FROZEN_PAIR")
    t = metrics(metrics.phase == "FROZEN_PAIR",:);
    y = 100*[t.control_angle_improvement,t.id_rms_improvement, ...
        t.prediction_residual_improvement,t.torque_ripple_improvement];
    if height(t) == 1
        bar(categorical({'Control angle','id RMS','Prediction residual', ...
            'Torque ripple'}),y(1,:));
        title("Active-off / active-on: "+t.case_id(1));
        yline(0,'k-');
    else
        bars = bar(y);
        xticks(1:height(t)); xticklabels(t.case_id); xtickangle(55);
        legendHandle = legend(bars,{'Control angle','id RMS','Prediction residual', ...
            'Torque ripple'},'Location','best');
        legendHandle.AutoUpdate = 'off';
        yline(0,'k-');
        title('Independent active-off / active-on pairs');
    end
    xlabel('Frozen case'); ylabel('Improvement (%)');
    grid on; entry.available = true;
else
    local_unavailable('Frozen-pair data is unavailable.');
end
local_export(fig,entry); close(fig);
end

function entry = local_drift_report(metrics,reportDir)
entry = local_entry('direction_speed_load_drift',reportDir);
fig = local_figure();
if ~isempty(metrics) && any(metrics.phase == "CONDITION_DRIFT")
    t = metrics(metrics.phase == "CONDITION_DRIFT",:);
    bar(t.lut_drift_e_deg,'FaceColor',[0.25 0.6 0.35]); hold on;
    yline(0.5,'r--','0.5 deg_e gate');
    xticks(1:height(t)); xticklabels(t.case_id); xtickangle(45);
    ylabel('Independent shadow LUT drift (deg_e)');
    title('Direction, speed, and load consistency'); grid on;
    entry.available = true;
else
    local_unavailable('Independent condition-drift data is unavailable.');
end
local_export(fig,entry); close(fig);
end

function entry = local_safety_report(stage2Dir,reportDir)
entry = local_entry('safety_constraints',reportDir);
path = fullfile(stage2Dir,'training','periodic_combined','M64', ...
    'lut_nodes.csv');
fig = local_figure();
if isfile(path)
    t = readtable(path); M = height(t); p = 21; epsilon = 0.1;
    active = t.active_e_rad;
    delta = circshift(active,-1)-active;
    margin = 1-delta/(p*2*pi/M);
    tiledlayout(2,1);
    nexttile; plot(t.node,rad2deg(active),'LineWidth',1.3); hold on;
    yline(25,'r--'); yline(-25,'r--'); ylabel('Active LUT (deg_e)'); grid on;
    title('Amplitude constraint');
    nexttile; plot(t.node,margin,'LineWidth',1.3); hold on;
    yline(epsilon,'r--'); xlabel('M64 node'); ylabel('E51 margin'); grid on;
    title('Periodic monotonicity margin'); entry.available = true;
else
    local_unavailable('Safety-constraint data is unavailable.');
end
local_export(fig,entry); close(fig);
end

function entry = local_cost_report(reportDir)
entry = local_entry('compute_storage_cost',reportDir);
cost = local_cost_table();
fig = local_figure();
yyaxis left
bar(categorical("M"+string(cost.nodes)),cost.scheme4_state_bytes);
ylabel('Fixed Scheme-4 state (bytes)');
yyaxis right
plot(categorical("M"+string(cost.nodes)),cost.nominal_operations_per_update, ...
    'o-','LineWidth',1.4); ylabel('Nominal arithmetic operations / update');
title('Fixed storage and per-sample cost'); grid on; entry.available = true;
local_export(fig,entry); close(fig);
end

function tableValue = local_cost_table()
nodes = [64;128];
% Six double vectors, one uint32 vector, one logical vector, plus a small
% scalar-state allowance. No sample history is stored.
scheme4StateBytes = 6*8*nodes + 4*nodes + nodes + 256;
runtimeLutBytes = 512*8*ones(2,1);
nominalOperations = 22*ones(2,1);
tableValue = table(nodes,scheme4StateBytes,runtimeLutBytes, ...
    nominalOperations,'VariableNames',{'nodes','scheme4_state_bytes', ...
    'runtime_lut_512_bytes','nominal_operations_per_update'});
end

function entry = local_entry(name,dirPath)
entry = struct('name',name,'available',false, ...
    'png',fullfile(dirPath,[name '.png']), ...
    'pdf',fullfile(dirPath,[name '.pdf']));
end

function fig = local_figure()
fig = figure('Visible','off','Color','w','Position',[100 100 1050 620]);
end

function local_unavailable(message)
axis off; text(0.5,0.55,'Stage-2 report unavailable', ...
    'HorizontalAlignment','center','FontSize',16,'FontWeight','bold');
text(0.5,0.43,message,'HorizontalAlignment','center','FontSize',11, ...
    'Interpreter','none');
end

function local_export(fig,entry)
exportgraphics(fig,entry.png,'Resolution',160);
exportgraphics(fig,entry.pdf,'ContentType','vector');
end

function value = local_optional_hash(path)
if isfile(path), value = file_sha256(path); else, value = ''; end
end

function value = local_iso_time()
t = datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
value = char(t);
end
