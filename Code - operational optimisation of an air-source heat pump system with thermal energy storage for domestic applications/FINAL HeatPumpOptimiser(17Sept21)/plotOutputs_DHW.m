function [] = plotOutputs_DHW(OperationCost,COP,COPsystem,Qhp,Qeh,Wgrid,Wpv,Cimp,GlobTiltIrr,...
    Ddhw,T,Text,tankEnergy,coldWaterHeight,aSH,aDHW,TimeResInputs,nDays,DailyResults)

% This function is used to plot all outputs resulting from the operation of
% the heat pump and thermal storage system. 

% Preparation
%=======================================

% time
t1 = datetime(0,0,0,0,0,TimeResInputs);
t2 = datetime(0,0,0,nDays*24,0,0);
t = t1:seconds(TimeResInputs):t2;

% colours for plots
blue   = [0.000, 0.447, 0.741];
red    = [0.850, 0.325, 0.098];	
green  = [0.466, 0.674, 0.188];
yellow = [0.929, 0.694, 0.125];
purple = [0.494, 0.184, 0.556];

set(gca,'defaulttextfontsize',11,'defaultaxesfontsize',11,...
        'defaulttextfontname','Arial','defaultaxesfontname','Arial');

QhpSH = Qhp .* aSH;
QhpDHW = Qhp .* aDHW;
QehSH = Qeh .* aSH;
QehDHW = Qeh .* aDHW;

Daily.QhpSH = reshape(QhpSH, length(QhpSH)/7, 7);
Daily.QhpDHW = reshape(QhpDHW, length(QhpDHW)/7, 7);
Daily.QehSH = reshape(QehSH, length(QehSH)/7, 7);
Daily.QehDHW = reshape(QehDHW, length(QehDHW)/7, 7);

Daily.Text =  reshape(Text, length(Text)/7, 7);
Daily.AverageText = mean(Daily.Text,2);

Daily.Cimp =  reshape(Cimp, length(Cimp)/7, 7);
Daily.AverageCimp = mean(Daily.Cimp,2);

Daily.GTI =  reshape(GlobTiltIrr, length(GlobTiltIrr)/7, 7);
Daily.AverageGTI = mean(Daily.GTI,2);

figure('Position',[50 0 800 1200]);

% Heat pump and electric heater output for SH
% =====================================


subplot(4,1,1); box on; hold on; colororder({'k','k'})
ylabel('Q_{SH} (kW)');
 
for i =1:7
    k = stairs(t(1:length(t)/7),Daily.QhpSH(:,i)/1000,'linestyle','-');
    hold on;
    x = [k.XData(1),repelem(k.XData(2:end),2)];
    y = [repelem(k.YData(1:end-1),2),k.YData(end)];
    bottom = 0;
    a = fill([x,fliplr(x)],[y,bottom*ones(size(y))], 'r');
    a.FaceAlpha = 0.2;
    a.FaceColor  = red;
    a.EdgeColor  = red;

    m = stairs(t(1:length(t)/7),Daily.QehSH(:,i)/1000,'linestyle','-');
    x = [m.XData(1),repelem(m.XData(2:end),2)];
    y = [repelem(m.YData(1:end-1),2),m.YData(end)];
    bottom = 0;
    b = fill([x,fliplr(x)],[y,bottom*ones(size(y))], 'r');
    b.FaceAlpha = 0.2;
    b.FaceColor  = blue;
    b.EdgeColor  = blue;
    
end

hold on;

legend([a(1),b(1)],'Q_{HP}','Q_{EH}');
datetick('x','HH:MM','keeplimits')

yyaxis right;
% c = plot(t(1:length(t)/7),Daily.AverageText-273.15);
% ylabel('T_{amb} (°C)');
% legend([a(1),b(1),c(1)],'Q_{HP}','Q_{EH}','T_{amb}');

% c = plot(t(1:length(t)/7),Daily.AverageCimp*100);
% ylabel('P_{elec} (pence/kWh)');
% legend([a(1),b(1),c(1)],'Q_{HP}','Q_{EH}','P_{elec}');

c = plot(t(1:length(t)/7),Daily.AverageGTI);
ylabel('Global tilt irradiation (Wh/m^{2})');
legend([a(1),b(1),c(1)],'Q_{HP}','Q_{EH}','Global tilt irradiation (Wh/m^{2})');

% Heat pump and electric heater output for DHW
% =====================================
subplot(4,1,2); box on; hold on;
ylabel('Q_{DHW} (kW)');

for i =1:7
    k = stairs(t(1:length(t)/7),Daily.QhpDHW(:,i)/1000,'linestyle','-');
    hold on;
    x = [k.XData(1),repelem(k.XData(2:end),2)];
    y = [repelem(k.YData(1:end-1),2),k.YData(end)];
    bottom = 0;
    a = fill([x,fliplr(x)],[y,bottom*ones(size(y))], 'r');
    a.FaceAlpha = 0.2;
    a.FaceColor  = red;
    a.EdgeColor  = red;

    m = stairs(t(1:length(t)/7),Daily.QehDHW(:,i)/1000,'linestyle','-');
    x = [m.XData(1),repelem(m.XData(2:end),2)];
    y = [repelem(m.YData(1:end-1),2),m.YData(end)];
    bottom = 0;
    b = fill([x,fliplr(x)],[y,bottom*ones(size(y))], 'r');
    b.FaceAlpha = 0.2;
    b.FaceColor  = blue;
    b.EdgeColor  = blue;
    
end
legend([a(1),b(1)],'Q_{HP}','Q_{EH}');
datetick('x','HH:MM','keeplimits')

yyaxis right;

% c = plot(t(1:length(t)/7),Daily.AverageText-273.15);
% ylabel('T_{amb} (°C)');
% legend([a(1),b(1),c(1)],'Q_{HP}','Q_{EH}','T_{amb}');

% c = plot(t(1:length(t)/7),Daily.AverageCimp*100);
% ylabel('P_{elec} (pence/kWh)');
% legend([a(1),b(1),c(1)],'Q_{HP}','Q_{EH}','P_{elec}');

c = plot(t(1:length(t)/7),Daily.AverageGTI);
ylabel('Global tilt irradiation (Wh/m^{2})');
legend([a(1),b(1),c(1)],'Q_{HP}','Q_{EH}','Global tilt irradiation (Wh/m^{2})');

% hold on;
% yyaxis right;
% c = plot(t(1:length(t)/7),Daily.AverageGTI);
% ylabel('Global tilt irradiation (Wh/m^{2})');
% legend([a(1),b(1),c(1)],'Q_{HP}','Q_{EH}','Global tilt irradiation (Wh/m^{2})');

% yyaxis right;
% c = plot(t(1:length(t)/7),Daily.AverageText-273.15);
% ylabel('T_{amb} (°C)');
% legend([a(1),b(1),c(1)],'Q_{HP}','Q_{EH}','T_{amb}');

% Power exchanged with the grid, electricity price and operational cost
% =======================================================================

subplot(4,1,3); box on; hold on;

stairs(t, Wgrid/1000,'LineWidth',1,'color',blue);
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('W_{grid}(kW)');

% Temperatures of thermal model
% ==============================

subplot(4,1,4); box on; hold on;

plot(t,Text-273.15,'-o','LineWidth',1,'color',green,'MarkerIndices',1:300:length(t))
plot(t,T(:,3)-273.15,'-*','LineWidth',1,'color',blue,'MarkerIndices',1:300:length(t))
plot(t,T(:,1)-273.15,'-+','LineWidth',1,'color',red,'MarkerIndices',1:300:length(t))
plot(t,T(:,5)-273.15,'-x','LineWidth',1,'color',yellow,'MarkerIndices',1:300:length(t))
plot(t,T(:,6)-273.15,'-^','LineWidth',1,'color',purple,'MarkerIndices',1:300:length(t));
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('T (\circC)');
ylim([0 70])
legend('Ambient','Internal space','Heat-pump outlet','Cylinder(top)','Cylinder (bottom)');

figure(); box on; hold on;
x = categorical({'Heat pump','Electric heater'});
x = reordercats(x,{'Heat pump','Electric heater'});

data =    [DailyResults.HeatPumpOutputSH  DailyResults.HeatPumpOutputDHW;...
           DailyResults.ElecHeatOutputSH  DailyResults.ElecHeatOutputDHW ];

bar(x,data,'stacked','FaceColor','flat') ;    
ylabel('Heat output (kWh/day)','Interpreter','latex')
legend('Space heating','Domestic hot water');

end
