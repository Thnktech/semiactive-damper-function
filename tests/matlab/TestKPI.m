classdef TestKPI < matlab.unittest.TestCase
    %TESTKPI Verifies kpi.m on synthetic signals with known answers (M2).

    properties
        t = (0:1e-3:10)'
    end

    methods (Test)
        % Known answer: the RMS of a sine is its amplitude / sqrt(2).
        function sine_rms_is_amplitude_over_sqrt2(tc)
            a = 2; s = a*sin(2*pi*1*tc.t);          % 8 whole periods in [2, 10] s
            K = kpi(tc.t, s, 10*s, 0.001*s, 1000);
            % The window holds 8001 samples: 8 periods + one endpoint where
            % sin = 0, so the discrete RMS is a/sqrt(2)*sqrt(8000/8001)
            % (-6.25e-5 relative). Tolerance 1e-4 covers that.
            tc.verifyEqual(K.rms_zs_ddot, a/sqrt(2), 'RelTol', 1e-4);
            tc.verifyEqual(K.rms_F_tire_dyn, 10*a/sqrt(2), 'RelTol', 1e-4);
            tc.verifyEqual(K.rms_F_tire_rel, 10*a/sqrt(2)/1000, 'RelTol', 1e-4);
            tc.verifyEqual(K.max_travel_mm, 2, 'AbsTol', 1e-9);
        end

        function rms_counts_a_constant_offset(tc)
            % RMS, not std: an offset is part of the KPI
            c = 0.5*ones(size(tc.t));
            K = kpi(tc.t, c, c, c, 1);
            tc.verifyEqual(K.rms_zs_ddot, 0.5, 'AbsTol', 1e-12);
        end

        % The start-up transient (t < 2 s) must not count (SC-C80 definition).
        function transient_before_t_skip_is_ignored(tc)
            s = zeros(size(tc.t)); s(tc.t < 2) = 100;   % large transient in the first 2 s
            K = kpi(tc.t, s, s, 0*s, 1);
            tc.verifyEqual(K.rms_zs_ddot, 0, 'AbsTol', 1e-12);
            tc.verifyEqual(K.rms_F_tire_dyn, 0, 'AbsTol', 1e-12);
        end

        % The optional t_skip argument must really change the window.
        function custom_t_skip_is_used(tc)
            s = double(tc.t >= 5);                       % 0 before 5 s, 1 after
            K2 = kpi(tc.t, s, s, s, 1);                  % default 2 s: mix of 0 and 1
            K5 = kpi(tc.t, s, s, s, 1, 5);               % from 5 s: all ones
            tc.verifyEqual(K5.rms_zs_ddot, 1, 'AbsTol', 1e-12);
            tc.verifyLessThan(K2.rms_zs_ddot, 1);
        end

        % Travel: the largest |zs - zu| over the WHOLE run, also inside the skipped
        % window and also when negative (compression and extension both use travel).
        function travel_uses_whole_run_and_absolute_value(tc)
            d = zeros(size(tc.t)); d(500) = -0.08;       % -80 mm peak at t = 0.499 s, inside the skipped window
            K = kpi(tc.t, 0*d, 0*d, d, 1);
            tc.verifyEqual(K.max_travel_mm, 80, 'AbsTol', 1e-9);
        end

        % Row or column vectors must give the same result (no silent broadcasting).
        function row_and_column_inputs_agree(tc)
            s = sin(2*pi*3*tc.t);
            Kc = kpi(tc.t, s, s, s, 1);
            Kr = kpi(tc.t', s', s', s', 1);
            tc.verifyEqual(Kr, Kc);
        end

        % Inputs of different length must stop with an error instead of a wrong KPI.
        function size_mismatch_errors(tc)
            s = sin(tc.t);
            tc.verifyError(@() kpi(tc.t, s(1:end-1), s, s, 1), 'kpi:size');
            tc.verifyError(@() kpi(tc.t, s, s(1:end-1), s, 1), 'kpi:size');
            tc.verifyError(@() kpi(tc.t, s, s, s(1:end-1), 1), 'kpi:size');
        end

        % A run shorter than t_skip has nothing to evaluate: error, not NaN.
        function empty_window_errors(tc)
            s = sin(tc.t);
            tc.verifyError(@() kpi(tc.t, s, s, s, 1, 20), 'kpi:window');
        end
    end
end
