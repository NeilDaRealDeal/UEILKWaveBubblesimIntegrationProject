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
% Increase simulation length to ensure tapering off
% Fix Weird Simulation Results

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
       ts; %true source, set in code
   end
   methods(Static)
      function sourc = set_up_true_source(obj)
          sourc.p_mask = obj.true_kwavearray.getArrayBinaryMask(obj.kgrid);
          sourc.p = obj.true_kwavearray.getDistributedSourceSignal(obj.kgrid, obj.true_source_signal);
      end
      function sourc = set_up_sim_source(obj, emitted)
          sim_kwavearray = obj.true_kwavearray;
          sim_source_signal = obj.true_source_signal;
          sim_kwavearray.addCustomElement([obj.microbubble_location_x + obj.deltax, obj.microbubble_location_x - obj.deltax, obj.microbubble_location_x, obj.microbubble_location_x, obj.microbubble_location_x, obj.microbubble_location_x; obj.microbubble_location_y, obj.microbubble_location_y, obj.microbubble_location_y + obj.deltax, obj.microbubble_location_y - obj.deltax, obj.microbubble_location_y, obj.microbubble_location_y; obj.microbubble_location_z, obj.microbubble_location_z, obj.microbubble_location_z, obj.microbubble_location_z, obj.microbubble_location_z + obj.deltax, obj.microbubble_location_z - obj.deltax], (4*obj.deltax^3)/3, 3, 'bubble');
          sim_source_signal(size(sim_source_signal, 1) + 1, 1 : length(emitted)) = emitted;
          sourc.p_mask = sim_kwavearray.getArrayBinaryMask(obj.kgrid);
          sourc.p = sim_kwavearray.getDistributedSourceSignal(obj.kgrid, sim_source_signal);
      end
      function driven = convert_sensed_to_driven(obj, sensed) %output driven (just processing, especially conversion to intervals of 10^-8 from 10^-7)
        %Note: For now, we assume that sensed time resolution is less than
        %the driven.
        kwaverecipdtscale = 7; %Double Check This
        bubblesimrecipdtscale = 8;
        drive = zeros(1, 10^(bubblesimrecipdtscale - kwaverecipdtscale) * length(sensed));
        scale_up = 10^(bubblesimrecipdtscale - kwaverecipdtscale);
        scale_down = 10^(kwaverecipdtscale - bubblesimrecipdtscale);
        for r = 1:length(drive)
            if ceil(scale_down*r) == floor(scale_down*r)
                drive(r) = sensed(floor(scale_down*r));
            elseif floor(scale_down*r) == 0
                drive(r) = (mod(r, scale_up)*sensed(ceil(scale_down*r))/scale_up);
            else
                drive(r) = ((mod(r, scale_up)*sensed(ceil(scale_down*r)) + (scale_up - mod(r, scale_up))*sensed(floor(scale_down*r)))/scale_up);
            end
        end
        driven = drive;
      end
      function scattered = convert_driven_to_scattered(obj, driven) %output scattered - note: driven is in intervals of 10^-8
          time = zeros(1, length(driven));
          for r = 1:length(time)
              time(r) = (r-1)*(10^(-8));
          end
          %If below still doesn't work, shift to a sampling rate of 100
          disp(size(driven));
          disp("Driven:");
          %disp(driven);
          disp(size(time));
          disp("Time");
          %disp(time);
          [particle2,pulse2,linear2,simulation2,graph2] = UEILFotisNeilBubblesimCallBackCustomPulse(obj.gas_model, obj.radius, obj.thickness, obj.shear, obj.viscocity, obj.liquid_name, '30', '2.5', '10', '100', time.', driven.');
          scattered = simulation2.pr * obj.artificial_scale_up;
      end
      function emitted = convert_scattered_to_emitted(obj, scattered) %output emitted (just processing)
          disp(size(scattered));
          emitted = scattered.'/obj.n;
      end

      function sensed = run_sensing_sim(obj) %Output bubble sensed pulse (Note: just sense bubble)
         true_source = SingleCavitationSimulation.set_up_true_source(obj);
         %obj.ts = true_source;
         now_sensor.mask = zeros(obj.kgrid.Nx, obj.kgrid.Ny, obj.kgrid.Nz);
         now_sensor.mask(obj.microbubble_location_x, obj.microbubble_location_y, obj.microbubble_location_z) = 1; 
         [data] = kspaceFirstOrder3D(obj.kgrid, obj.medium, obj.ts, now_sensor, obj.input_args{:}); %Note: After input_args, inputs are temporary
         sensed = data;
      end

      function sensor_data = run_true_sim(obj, sensed) %Output true sensor data
          bubble_emission = SingleCavitationSimulation.convert_scattered_to_emitted(obj, SingleCavitationSimulation.convert_driven_to_scattered(obj, SingleCavitationSimulation.convert_sensed_to_driven(obj, sensed)));
          sim_source = SingleCavitationSimulation.set_up_sim_source(obj, bubble_emission);
          [data] = kspaceFirstOrder3D(obj.kgrid, obj.medium, sim_source, obj.true_sensor, obj.input_args{:}); %Note: After input_args, inputs are temporary
          sensor_data = data;
      end
      
      function sensor_data = run(obj) %Output true sensor data
         sensed = SingleCavitationSimulation.run_sensing_sim(obj);
         sensor_data = SingleCavitationSimulation.run_true_sim(obj, sensed);
      end
   end
end