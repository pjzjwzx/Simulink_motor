function save_stage1_case_plot(path, time, estimate, truth, valid, caseId)
%SAVE_STAGE1_CASE_PLOT Save deterministic Stage 1 diagnostic panels.

fig = figure('Visible','off','Color','w','Position',[100 100 1100 700]);
cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
nexttile;
plot(time,rad2deg(truth),'k-','LineWidth',1.1); hold on;
plot(time,rad2deg(estimate),'Color',[0 0.45 0.74],'LineWidth',0.9);
ylabel('electrical deg'); grid on;
legend('truth','pseudo angle','Location','best');
title(strrep(caseId,'_','\_'));
nexttile;
errorDeg = rad2deg(angle(exp(1i*(estimate-truth))));
plot(time,errorDeg,'Color',[0.85 0.33 0.1]); hold on;
invalid = ~logical(valid);
if any(invalid), plot(time(invalid),errorDeg(invalid),'.','Color',[0.5 0.5 0.5]); end
xlabel('time (s)'); ylabel('circular error (deg_e)'); grid on;
exportgraphics(fig,path,'Resolution',150);
end

