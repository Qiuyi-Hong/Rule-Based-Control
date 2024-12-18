function [] = plotInputs(ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw,TimeResInputs)

% Plots of inputs
% ==============================================

% X-axis
t1 = datetime(0,0,0,0,0,TimeResInputs);
t2 = datetime(0,0,0,7*24,0,0);
t = t1:seconds(TimeResInputs):t2;

set(gca,'defaulttextfontsize',11,'defaultaxesfontsize',11,...
        'defaulttextfontname','Arial','defaultaxesfontname','Arial');
    
% Electricity prices in the UK and Germany
% =========================================

figure('Position',[100 100 800 600]);
box on;
subplot(2,1,1);
stairs(t,ElecPriceUK);
title('UK')
ylabel('Electricity price (pence/kWh)');
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylim([0 30])

subplot(2,1,2);
stairs(t,ElecPriceGermany);
title('Germany')
ylabel('Electricity price (pence/kWh)');
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylim([0 30])

%Domestic hot water demand (kg/s)
% =====================================

figure();
box on
stairs(t,Ddhw);
ylabel('Domestic hot water demand (kg/s)');
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})

% Ambient temperature (°C) in Oban and Munich 
% ==============================================

figure('Position',[100 100 800 600]);
box on;
subplot(2,1,1);
plot(t,WeatherOban.Text);
title('Oban')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylim([0 35])

ylabel('T_{ambient} (^oC)');
subplot(2,1,2);
plot(t,WeatherMunich.Text);
title('Munich')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})

ylabel('T_{ambient}(^oC)');
ylim([0 35])

% Global horizontal irradiation in Oban and Munich
% ================================================

figure('Position',[100 100 800 600]);
box on
subplot(2,1,1);
plot(t,WeatherOban.GlobHorIrr);
title('Oban')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Global horizontal irradiation (Wh/m2)');
subplot(2,1,2);
plot(t,WeatherMunich.GlobHorIrr);
title('Munich')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Global horizontal irradiation (Wh/m2)');

% Direct normal irradiation in Oban and Munich
% ============================================

figure('Position',[100 100 800 600]);
box on
subplot(2,1,1);
plot(t,WeatherOban.DirNormIrr);
title('Oban')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Direct normal irradiation (Wh/m2)');
subplot(2,1,2);
plot(t,WeatherMunich.DirNormIrr);
title('Munich')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Direct normal irradiation (Wh/m2)');

% Diffuse horizontal irradiation in Oban and Munich
% =====================================================

figure('Position',[100 100 800 600]);
box on
subplot(2,1,1);
plot(t,WeatherOban.DiffHorIrr);
title('Oban')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Diffuse horizontal irradiation (Wh/m2)');
subplot(2,1,2);
plot(t,WeatherMunich.DiffHorIrr);
title('Munich')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Diffuse horizontal irradiation (Wh/m2)');

% Extraterrestrial normal irradiation in Oban and Munich
% ======================================================
fig = figure('Position',[100 100 800 600]);
box on
set(fig,'Position',[100 100 800 600]);
subplot(2,1,1);
plot(t,WeatherOban.ExtNormIrr);
title('Oban')
legend('hot summer', 'cold winter', 'typical spring', ...
        'typical summer','typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Extraterrestrial normal irradiation (Wh/m2)');
subplot(2,1,2);
plot(t,WeatherMunich.ExtNormIrr);
title('Munich')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Extraterrestrial normal irradiation (Wh/m2)');

end