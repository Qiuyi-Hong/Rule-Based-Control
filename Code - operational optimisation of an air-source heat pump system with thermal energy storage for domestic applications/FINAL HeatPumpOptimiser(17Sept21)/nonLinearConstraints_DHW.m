function [C,Ceq] = nonLinearConstraints_DHW(x,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,ICs,objectiveFunctionName)
[~,~,...
    ~,~,...
    T,~,~,~,~,~,~,~,...
    ~,~,~,~,...
    ~,~,...
    NtimesDHWdemandNotMet,NtimesSHdemandNotMet,~,...
    ~,~,~,~] = ...
    OptimisedCaseModel_DHW(x,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,ICs,objectiveFunctionName);

% Three non-linear inequality constraints:
%===================================

% (1) The temperature of the primary loop should remain below a minimum value
% (2) The demand for DHW is allowed not to be met a limited number of times 
% (3) The demand for SH is allowed not to be met a limited number of times 

C = [(T(:,1)-(70+273.15))' NtimesDHWdemandNotMet-5 NtimesSHdemandNotMet-5]   ;

% No equality constraints
Ceq = [] ;

end