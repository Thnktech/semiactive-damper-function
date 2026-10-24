classdef TestRoads < matlab.unittest.TestCase
    %TESTROADS Verifies road_iso8608 (ISO 8608-based random roads) and road_bump (SC-BUMP).
    %   PSD is checked as power in spatial-frequency bands against the target
    %   Gd(n) = Gd0*(n/n0)^-2 (no Signal Processing Toolbox needed).

    properties (Constant)
        Gd0 = struct('A', 16e-6, 'B', 64e-6, 'C', 256e-6, 'D', 1024e-6)   % m^3, n0 = 0.1
        Bands = [0.02 0.05; 0.05 0.2; 0.2 0.5; 0.5 2.0]                   % cycles/m
    end

    properties (TestParameter)
        roadClass = {'A', 'B', 'C', 'D'}
    end

    methods (Test)
        % The road must have the ISO 8608 PSD of its class: power in four bands
        % within 10 %. Long run (120 s) so the estimate is stable.
        function psd_matches_target_in_bands(tc, roadClass)
            V = 80/3.6;
            [t, zr] = road_iso8608(roadClass, 80, 120, 1);
            keep = t > 1;                                   % skip fade-in
            [Pest, Pexp] = bandPower(zr(keep), V*1e-3, tc.Bands, tc.Gd0.(roadClass));
            for b = 1:size(tc.Bands, 1)
                tc.verifyEqual(Pest(b), Pexp(b), 'RelTol', 0.10, sprintf( ...
                    'Class %s, band %.2f-%.2f cycles/m: power %.3g vs target %.3g m^2', ...
                    roadClass, tc.Bands(b, 1), tc.Bands(b, 2), Pest(b), Pexp(b)));
            end
        end

        function classes_scale_by_factor_two(tc)
            % Gd0 quadruples per class, same seed -> same phases -> std doubles exactly
            s = cellfun(@(c) std(getfield(road(c), 'zr')), {'A', 'B', 'C', 'D'});
            tc.verifyEqual(s(2:end)./s(1:end-1), [2 2 2], 'RelTol', 1e-9);
            function r = road(c), [~, r.zr] = road_iso8608(c, 80, 20, 1); end
        end

        % Repeatability: every strategy and every rerun must see the same road.
        function same_seed_same_road(tc)
            [~, z1] = road_iso8608('C', 80, 10, 7);
            [~, z2] = road_iso8608('C', 80, 10, 7);
            tc.verifyEqual(z1, z2);
        end

        % The seed must really matter (it was once set after the random numbers).
        function different_seed_different_road(tc)
            [~, z1] = road_iso8608('C', 80, 10, 7);
            [~, z2] = road_iso8608('C', 80, 10, 8);
            tc.verifyGreaterThan(max(abs(z1 - z2)), 1e-3);
        end

        % A road is a property of the place, not of the time: driving half as fast
        % must show the same profile, twice as slowly.
        function road_depends_on_distance_not_time(tc)
            % The same seed gives the same profile in distance: z80(t) = z40(2t) once faded in
            [t80, z80] = road_iso8608('C', 80, 10, 3);
            [~,   z40] = road_iso8608('C', 40, 20, 3);
            k = find(t80 >= 2);
            tc.verifyEqual(z80(k), z40(2*(k-1) + 1), 'AbsTol', 1e-12);
        end

        function road_does_not_repeat(tc)
            % With equally spaced frequencies the sum repeats after 1/dn (up to a
            % common phase rotation): the road 1/dn further on correlates ~0.8
            % with the road here, for every seed. With frequencies randomized
            % inside each bin the correlation is random with mean ~0. A single
            % 300 m window is dominated by a few long waves, so the check uses
            % the mean over 10 seeds.
            period = 1/((2.83 - 0.011)/1000);        % 1/bin width [m]
            V = 80/3.6;
            r = zeros(1, 10);
            for s = 1:10
                [t, zr] = road_iso8608('C', 80, ceil((330 + period)/V) + 1, s);
                x = V*t;
                a = x >= 30 & x <= 330;
                cc = corrcoef(zr(a), interp1(x, zr, x(a) + period));
                r(s) = cc(1, 2);
            end
            tc.verifyLessThan(abs(mean(r)), 0.15, sprintf( ...
                'Road %.0f m further on correlates %.2f on average with the road here: road repeats', ...
                period, mean(r)));
        end

        % Fade-in: the car must not start on a sudden road step.
        function smooth_start(tc)
            [~, zr] = road_iso8608('C', 80, 5, 1);
            tc.verifyEqual(zr(1), 0, 'Road must start at 0 (fade-in)');
        end

        % Only classes A-D exist in this generator.
        function invalid_class_errors(tc)
            tc.verifyError(@() road_iso8608('E', 80, 1, 1), ?MException);
        end

        % SC-BUMP geometry: height, start, duration L/V, flat before and after, peak
        % in the middle; checked to within one 1 ms sample.
        function bump_shape(tc)
            h = 0.05; L = 0.5; v = 18; t0 = 1;
            [t, zr] = road_bump(h, L, v, 3, t0);
            V = v/3.6;
            tc.verifyEqual(max(zr), h, 'AbsTol', 1e-6, 'Bump height');
            on = zr > 0;
            tc.verifyEqual(t(find(on, 1)), t0, 'AbsTol', 1.5e-3, 'Bump start time');
            tc.verifyEqual(sum(on)*1e-3, L/V, 'AbsTol', 2e-3, 'Bump duration = L/V');
            tc.verifyEqual(zr(t < t0), zeros(nnz(t < t0), 1), 'Flat before the bump');
            tc.verifyEqual(zr(t > t0 + L/V + 1e-3), zeros(nnz(t > t0 + L/V + 1e-3), 1), 'Flat after the bump');
            [~, kpk] = max(zr);
            tc.verifyEqual(t(kpk), t0 + L/(2*V), 'AbsTol', 1.5e-3, 'Peak at mid-bump');
        end
    end
end

function [Pest, Pexp] = bandPower(z, dx, bands, Gd0)
%BANDPOWER One-sided power of z in spatial-frequency bands (Hann-windowed periodogram).
n0 = 0.1;
z = z - mean(z);
Ns = numel(z);
w = 0.5 - 0.5*cos(2*pi*(0:Ns-1)'/(Ns-1));
X = fft(z.*w);
P = 2*abs(X(1:floor(Ns/2))).^2/(Ns^2*mean(w.^2));   % one-sided power per bin [m^2]
n = (0:floor(Ns/2)-1)'/(Ns*dx);                      % [cycles/m]
Pest = zeros(size(bands, 1), 1); Pexp = Pest;
for b = 1:size(bands, 1)
    in = n >= bands(b, 1) & n < bands(b, 2);
    Pest(b) = sum(P(in));
    Pexp(b) = Gd0*n0^2*(1/bands(b, 1) - 1/bands(b, 2));   % integral of Gd(n) over the band
end
end
