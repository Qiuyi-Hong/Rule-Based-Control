function [] = plotInputsPaper(ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw,TimeResInputs)

% Plots of inputs
% ==============================================

% X-axis
t1 = datetime(0,0,0,0,0,TimeResInputs);
t2 = datetime(0,0,0,24,0,0);
t3 = datetime(0,0,0,24*7,0,0);
tDay = t1:seconds(TimeResInputs):t2;
tWeek = t1:seconds(TimeResInputs):t3;
set(gca,'defaulttextfontsize',11,'defaultaxesfontsize',11,...
        'defaulttextfontname','Arial','defaultaxesfontname','Arial');
    
% Electricity prices in the UK and Germany
% =========================================
ElecPriceUKshaped = reshape(ElecPriceUK, [720,7]);
ElecPriceUKmean = mean(ElecPriceUKshaped');

ElecPriceGermanyshaped = reshape(ElecPriceGermany, [720,7]);
ElecPriceGermanymean = mean(ElecPriceGermanyshaped');

blue   = [0.000, 0.447, 0.741];
red    = [0.850, 0.325, 0.098];	

figure('Position',[100 100 800 250]);
box on; hold on;
plot(tDay,ElecPriceUKshaped(:,1),'-^','color',blue,'MarkerIndices',1:30:length(ElecPriceUKshaped));
plot(tDay,ElecPriceGermanyshaped(:,4),'-o','color',red,'MarkerIndices',1:30:length(ElecPriceUKshaped));
ylabel('Electricity price (pence/kWh)');
ylim([0 30])
xlabel('');
legend('UK','Germany');
datetick('x','HH:MM','keeplimits')

%Domestic hot water demand (kg/s)
% =====================================
DHWshaped = reshape(Ddhw, [720,7]);

figure('Position',[100 100 800 250]);
box on; hold on;
plot(tDay,DHWshaped(:,1),'-','color',blue);
plot(tDay,DHWshaped(:,6),'-.','color',red);
ylabel('DHW demand (kg/s)');
legend('Typical week day','Typical weekend day')
datetick('x','HH:MM','keeplimits')

% Ambient temperature (°C) in Oban and Munich 
% ==============================================

figure('Position',[100 100 800 600]);
subplot(2,1,1); hold on; box on;
plot(tWeek,WeatherOban.Text(:,3),'-^','MarkerIndices',1:200:length(WeatherOban.Text(:,1)));
plot(tWeek,WeatherOban.Text(:,4),'-+','MarkerIndices',1:200:length(WeatherOban.Text(:,1)));
plot(tWeek,WeatherOban.Text(:,5),'-s','MarkerIndices',1:200:length(WeatherOban.Text(:,1)));
plot(tWeek,WeatherOban.Text(:,6),'-v','MarkerIndices',1:200:length(WeatherOban.Text(:,1)));
title('Oban')
legend('typical spring','typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylim([-10 30])

ylabel('T_{amb} (^oC)');
subplot(2,1,2); hold on; box on;
plot(tWeek,WeatherMunich.Text(:,3),'-^','MarkerIndices',1:200:length(WeatherMunich.Text(:,1)));
plot(tWeek,WeatherMunich.Text(:,4),'-+','MarkerIndices',1:200:length(WeatherMunich.Text(:,1)));
plot(tWeek,WeatherMunich.Text(:,5),'-s','MarkerIndices',1:200:length(WeatherMunich.Text(:,1)));
plot(tWeek,WeatherMunich.Text(:,6),'-v','MarkerIndices',1:200:length(WeatherMunich.Text(:,1)));
title('Munich')
legend('typical spring','typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('T_{amb}(^oC)');
ylim([-10 30])

% Global horizontal irradiation in Oban and Munich
% ================================================

figure('Position',[100 100 800 600]);
box on
subplot(2,1,1);
plot(tWeek,WeatherOban.GlobHorIrr);
title('Oban')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Global horizontal irradiation (Wh/m2)');
subplot(2,1,2);
plot(tWeek,WeatherMunich.GlobHorIrr);
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
plot(tWeek,WeatherOban.DirNormIrr);
title('Oban')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Direct normal irradiation (Wh/m2)');
subplot(2,1,2);
plot(tWeek,WeatherMunich.DirNormIrr);
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
plot(tWeek,WeatherOban.DiffHorIrr);
title('Oban')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Diffuse horizontal irradiation (Wh/m2)');
subplot(2,1,2);
plot(tWeek,WeatherMunich.DiffHorIrr);
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
plot(tWeek,WeatherOban.ExtNormIrr);
title('Oban')
legend('hot summer', 'cold winter', 'typical spring', ...
        'typical summer','typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Extraterrestrial normal irradiation (Wh/m2)');
subplot(2,1,2);
plot(tWeek,WeatherMunich.ExtNormIrr);
title('Munich')
legend('hot summer', 'cold winter', 'typical spring',...
        'typical summer', 'typical autumn', 'typical winter')
xticklabels({'Day 1', 'Day 2','Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7',''})
ylabel('Extraterrestrial normal irradiation (Wh/m2)');

end