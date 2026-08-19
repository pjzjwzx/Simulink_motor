function result = generate_stage2_learning_evolution(stage2Dir,profileId)
%GENERATE_STAGE2_LEARNING_EVOLUTION Visualize LUT evolution at every solve.

if nargin < 2, profileId = 'periodic_combined'; end
if ~isfolder(stage2Dir)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    projectRelativeDir = fullfile(projectRoot,stage2Dir);
    if isfolder(projectRelativeDir)
        stage2Dir = projectRelativeDir;
    end
end
assert(isfolder(stage2Dir),'anglelut:Stage2EvolutionPath', ...
    'Stage-2 result directory is missing.');
inputPath = fullfile(stage2Dir,'training',char(profileId),'M64', ...
    'scheme4_state.mat');
assert(isfile(inputPath),'anglelut:Stage2EvolutionInput', ...
    'M64 learning history is missing for %s.',profileId);
loaded = load(inputPath,'history','reference');
[metrics,summary] = compute_stage2_learning_metrics( ...
    loaded.history,loaded.reference);
reportDir = fullfile(stage2Dir,'reports');
if ~isfolder(reportDir), mkdir(reportDir); end
csvPath = fullfile(reportDir,'lut_learning_evolution.csv');
jsonPath = fullfile(reportDir,'lut_learning_evolution.json');
pngPath = fullfile(reportDir,'lut_learning_evolution.png');
pdfPath = fullfile(reportDir,'lut_learning_evolution.pdf');
gifPath = fullfile(reportDir,'lut_learning_evolution.gif');
writetable(metrics,csvPath);

reference = double(loaded.reference.lut_e_rad(:));
M = numel(reference);
phiDeg = (0:M).'*360/M;
selected = unique(round(linspace(1,height(metrics),6)),'stable');
fig = figure('Visible','off','Color','w','Position',[80 80 1180 820]);
layout = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(layout,sprintf('Stage-2 LUT learning evolution — %s',profileId), ...
    'Interpreter','none');

nexttile(layout,[1 2]);
referenceHandle = plot(phiDeg,rad2deg([reference;reference(1)]), ...
    'Color',[0.12 0.12 0.12],'LineWidth',2.1, ...
    'DisplayName','Evaluation reference');
hold on;
orangeLight = [0.98 0.76 0.55];
orangeDark = [0.82 0.28 0.06];
snapshotHandles = gobjects(numel(selected),1);
snapshotLabels = strings(numel(selected),1);
for j = 1:numel(selected)
    k = selected(j);
    blend = (j-1)/max(numel(selected)-1,1);
    color = (1-blend)*orangeLight+blend*orangeDark;
    values = loaded.history.active_lut_e_rad(k,:).';
    snapshotHandles(j) = plot(phiDeg,rad2deg([values;values(1)]), ...
        'Color',color,'LineWidth',1.15+0.25*(j == numel(selected)), ...
        'LineStyle',local_line_style(j));
    snapshotLabels(j) = sprintf('Solve %d (%.1f rev)', ...
        metrics.solve_count(k),metrics.mechanical_cycles(k));
end
xlabel('Raw mechanical angle (deg_m)');
ylabel('Electrical error / compensation (deg_e)');
title('Selected active-LUT snapshots'); grid on; xlim([0 360]);
legend([referenceHandle;snapshotHandles], ...
    [{'Evaluation reference'};cellstr(snapshotLabels)], ...
    'Location','eastoutside');

nexttile(layout);
semilogy(metrics.time_s,metrics.shadow_rmse_e_deg,'o--', ...
    'Color',[0.10 0.42 0.78],'MarkerFaceColor','w','LineWidth',1.3, ...
    'DisplayName','Shadow RMSE');
hold on;
semilogy(metrics.time_s,metrics.active_rmse_e_deg,'o-', ...
    'Color',[0.88 0.31 0.07],'MarkerFaceColor',[0.88 0.31 0.07], ...
    'LineWidth',1.6,'DisplayName','Active RMSE');
yline(1,'Color',[0.25 0.25 0.25],'LineStyle',':', ...
    'DisplayName','1 deg_e gate');
xlabel('Simulation time (s)'); ylabel('LUT circular RMSE (deg_e, log scale)');
title('Error versus learning time'); grid on; legend('Location','best');

nexttile(layout);
plot(metrics.time_s,metrics.active_improvement_percent,'o-', ...
    'Color',[0.88 0.31 0.07],'MarkerFaceColor',[0.88 0.31 0.07], ...
    'LineWidth',1.7);
hold on; yline(80,'Color',[0.25 0.25 0.25],'LineStyle',':', ...
    'Label','80% LUT gate','LabelHorizontalAlignment','left');
xlabel('Simulation time (s)'); ylabel('Improvement over zero LUT (%)');
title('Accumulated active-LUT improvement'); grid on; ylim([0 100]);
for k = [1,height(metrics)]
    text(metrics.time_s(k),metrics.active_improvement_percent(k), ...
        sprintf('  %.1f%%',metrics.active_improvement_percent(k)), ...
        'VerticalAlignment','bottom','FontSize',9);
end

exportgraphics(fig,pngPath,'Resolution',170);
exportgraphics(fig,pdfPath,'ContentType','vector');
close(fig);
local_write_animation(gifPath,loaded.history,loaded.reference,metrics,profileId);

gatePath = fullfile(stage2Dir,'gate.json');
result = struct('schema_version','angle-lut-stage2-learning-evolution-v1', ...
    'profile_id',char(profileId),'source_run_directory',stage2Dir, ...
    'input_path',inputPath,'input_sha256',file_sha256(inputPath), ...
    'gate_sha256',local_optional_hash(gatePath),'summary',summary, ...
    'outputs',struct('csv',csvPath,'json',jsonPath,'png',pngPath, ...
    'pdf',pdfPath,'gif',gifPath), ...
    'chart_question','Does the active LUT improve as learning accumulates?', ...
    'chart_takeaway',sprintf([ ...
    'Active RMSE fell from %.3f to %.3f deg_e; improvement rose from ' ...
    '%.1f%% to %.2f%% across %d effective solves.'], ...
    summary.first_active_rmse_e_deg,summary.final_active_rmse_e_deg, ...
    summary.first_improvement_percent,summary.final_improvement_percent, ...
    summary.solve_count),'evaluation_reference_only',true, ...
    'truth_feedback_used',false);
write_json_file(jsonPath,result);
end

function local_write_animation(path,history,reference,metrics,profileId)
referenceLut = double(reference.lut_e_rad(:));
M = numel(referenceLut);
phiDeg = (0:M).'*360/M;
fig = figure('Visible','off','Color','w','Position',[100 100 980 620]);
for k = 1:height(metrics)
    clf(fig);
    shadow = history.shadow_lut_e_rad(k,:).';
    active = history.active_lut_e_rad(k,:).';
    plot(phiDeg,rad2deg([referenceLut;referenceLut(1)]),'k-', ...
        'LineWidth',2.2,'DisplayName','Evaluation reference'); hold on;
    plot(phiDeg,rad2deg([shadow;shadow(1)]),'--', ...
        'Color',[0.10 0.42 0.78],'LineWidth',1.5,'DisplayName','Shadow');
    plot(phiDeg,rad2deg([active;active(1)]),'-', ...
        'Color',[0.88 0.31 0.07],'LineWidth',2.0,'DisplayName','Active');
    xlabel('Raw mechanical angle (deg_m)');
    ylabel('Electrical error / compensation (deg_e)');
    title(sprintf(['%s — solve %d/%d, t=%.3f s, %.2f rev\n' ...
        'active RMSE %.3f deg_e, improvement %.2f%%'],profileId, ...
        k,height(metrics),metrics.time_s(k),metrics.mechanical_cycles(k), ...
        metrics.active_rmse_e_deg(k),metrics.active_improvement_percent(k)), ...
        'Interpreter','none');
    xlim([0 360]); ylim([-22 17]); grid on; legend('Location','northeast');
    drawnow;
    frame = getframe(fig);
    [indexed,map] = rgb2ind(frame2im(frame),256);
    if k == 1
        imwrite(indexed,map,path,'gif','LoopCount',Inf,'DelayTime',0.55);
    else
        imwrite(indexed,map,path,'gif','WriteMode','append','DelayTime',0.55);
    end
end
close(fig);
end

function style = local_line_style(index)
styles = {'--','-.',':','--','-.','-'};
style = styles{min(index,numel(styles))};
end

function value = local_optional_hash(path)
if isfile(path), value = file_sha256(path); else, value = ''; end
end
