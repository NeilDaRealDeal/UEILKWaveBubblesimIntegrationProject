%[particle1,pulse1,linear1,simulation1,graph1] = UEILFotisNeilBubblesimCallBack('adiabatic', '1.5', '0.3', '20', '0.6', 'blood', '0.3', '20', '2.25', '100');
%[particle2,pulse2,linear2,simulation2,graph2] = UEILFotisNeilBubblesimCallBackCustomPulse('adiabatic', '1.5', '0.3', '20', '0.6', 'blood', '30', '2.5', '10', '100', pulse1(1).t, pulse1(1).p);
[particle3,pulse3,linear3,simulation3,graph3] = UEILFotisNeilBubblesimCallBack('adiabatic', '1.5', '0.3', '20', '0.6', 'blood', '30', '2.5', '15', '100');
%Frequency Issue