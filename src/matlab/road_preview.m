function zp = road_preview(P, zr)
%ROAD_PREVIEW Ideal look-ahead sensor of the preview MPC (D39).
%   zp = ROAD_PREVIEW(P, zr) returns the road height the sensor sees at each
%   1 ms sample: zp(t) = zr(t + T_L), T_L = (p+1)*Ts of P.mpcp (55 ms).
%   zr is the road under the wheel, one value per 1 ms sample from t = 0.
%   The harness feeds zp to controller input 9 (zr_preview).
%
%   The samples are shifted, not interpolated, so zp is exactly the road
%   ahead. After the end of the road the last height is held, as the From
%   Workspace block holds the road itself.

n = round((P.mpcp.p + 1)*P.mpcp.Ts/1e-3);
zr = zr(:);
zp = [zr(1+n:end); repmat(zr(end), min(n, numel(zr)), 1)];
end
