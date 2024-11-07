% To run a simulation, first set up the regular K-wave simulation,
% then plug the parameters into this method along with the microbubble
% location and parameters.

% Assumtions for all models: Same type of microbubbles, translational 
% force of wave is negligible, motion of microbubbles resulting from 
% blood flow is negligible, RP model holds perfectly, etc.
% wave scattering can be considered solely additive

% IMPORTANT: We will run 3d simulations, and although any sensor can
% be used, a kWaveArray transducer source must be utilized.

%Note: We will model the microbubble as a very small octohedron as a sphere
%approximation: potentially improve upon this later

% Notes for Next Steps:
% Multiple Bubble Simulation
% Check Validity of Convolution Approach, and If Wrong, Can Increase kwave.dt and Bubblesim dt 

classdef SingleCavitationSimulation
   properties
       microbubble_location_x %x_position of microbubble in grid_units
       microbubble_location_y %y_position of microbubble in grid_units
       microbubble_location_z %z_position of microbubble in grid_units
       microbubble_true_location_x %x_position of microbubble in meters
       microbubble_true_location_y %y_position of microbubble in meters
       microbubble_true_location_z %z_position of microbubble in meters
       gas_model %String, same as UEILFotisNeilBubblesimCallBack
       radius %String, same as UEILFotisNeilBubblesimCallBack
       thickness %String, same as UEILFotisNeilBubblesimCallBack
       shear %String, same as UEILFotisNeilBubblesimCallBack
       viscocity %String, same as UEILFotisNeilBubblesimCallBack
       liquid_name %String, same as UEILFotisNeilBubblesimCallBack
       kgrid %Same as array transducer example
       medium %Same as array transducer example
       true_kwavearray %Same as array transducer example
       true_source_signal %Same as array transducer example
       %true_source %Same as array transducer example
       true_sensor %Same as array transducer example 

       input_args %Same as array transducer example
       deltax %double meters, used to determine the size of the octahedral bubble (make as small as possible)
       n %int number of points in bubble source, equals 8 for octahedron
       artificial_scale_up;
   end
   methods(Static)
      function source = set_up_true_source(obj)
          source.p_mask = true_kwavearray.getArrayBinaryMask(kgrid);
          source.p = true_kwavearray.getDistributedSourceSignal(kgrid, true_source_signal);
      end
      function source = set_up_sim_source(obj, emitted)
          sim_kwavearray = true_kwavearray;
          sim_source_signal = true_source_signal;
          sim_kwavearray.addCustomElement([microbubble_position_x + deltax, microbubble_position_x - deltax, microbubble_position_x, microbubble_position_x, microbubble_position_x, microbubble_position_x; microbubble_position_y, microbubble_position_y, microbubble_position_y + deltax, microbubble_position_y - deltax, microbubble_position_y, microbubble_position_y; microbubble_position_z, microbubble_position_z, microbubble_position_z, microbubble_position_z, microbubble_position_z + deltax, microbubble_position_z - deltax], (4*dx^3)/3, 3, 'bubble');
          sim_source_signal(size(sim_source_signal, 1) + 1, 1 : length(emitted)) = emitted;
          source.p_mask = sim_kwavearray.getArrayBinaryMask(kgrid);
          source.p = sim_kwavearray.getDistributedSourceSignal(kgrid, sim_source_signal);
      end
      function driven = convert_sensed_to_driven(obj, sensed) %output driven (just processing, especially conversion to intervals of 10^-8 from 10^-7)
        %Note: For now, we assume that sensed time resolution is less than
        %the driven.
        kwaverecipdtscale = 7;
        bubblesimrecipdtscale = 8;
        drive = zeros(10^(bubblesimrecipdtscale - kwaverecipdtscale) * length(sensed));
        scale_up = 10^(bubblesimrecipdtscale - kwaverecipdtscale);
        scale_down = 10^(kwaverecipdtscale - bubblesimrecipdtscale);
        for r = 1:length(drive)
            if ceil(scale_down*r) == floor(scale_down*r)
                drive(r) = sensed(floor(scale_down*r));
            else
                drive(r) = ((mod(r, scale_up)*sensed(ceil(scale_down*r)) + (scale_up - mod(r, scale_up))*sensed(floor(scale_down*r)))/scale_up);
            end
        end
        driven = drive;
      end
      function scattered = convert_driven_to_scattered(obj, driven) %output scattered - note: driven is in intervals of 10^-8
          bubblesimrecipdtscale = 8;
          scale = 10^bubblesimrecipdtscale;
          time = zeros(1, scale);
          for r = 1:length(time)
              time(r) = (r-1)/scale;
          end
          [particle2,pulse2,linear2,simulation2,graph2] = UEILFotisNeilBubblesimCallBackCustomPulse(gas_model, radius, thickness, shear, viscocity, liquid_name, '30', '2.5', '10', '10', time, driven);
          scattered = simulation2.pr * artificial_scale_up;
      end
      function emitted = convert_scattered_to_emitted(obj, scattered) %output emitted (just processing)
          emitted = scattered/n;
      end
      function sensed = run_sensing_sim(obj) %Output bubble sensed pulse (Note: just sense bubble)
         true_source = set_up_true_source(obj);
         sensor.mask = zeros(Kgrid.Nx, Kgrid.Ny, Kgrid.Nz);
         sensor.mask(microbubble_location_x, microbubble_location_y, microbubble_location_z) = 1; 
         [data] = kspaceFirstOrder3D(kgrid, medium, true_source, sensor, input_args, 'DataCast', 'single', ...
            'PlotScale', [-1, 1] * source_amp); %Note: After input_args, inputs are temporary
         sensed = data;
      end
      function sensor_data = run_true_sim(obj, sensed) %Output true sensor data
          bubble_emission = convert_scattered_to_emitted(convert_driven_to_scattered(convert_sensed_to_driven(sensed)));
          sim_source = set_up_sim_source(obj, bubble_emission);
          [data] = kspaceFirstOrder3D(kgrid, medium, sim_source, true_sensor, input_args, 'DataCast', 'single', ...
            'PlotScale', [-1, 1] * source_amp);
          sensor_data = data;
      end
      function sensor_data = run(obj) %Output true sensor data
         sensor_data = run_true_sim(obj, run_sensing_sim(obj));
      end
   end
end