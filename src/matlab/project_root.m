function root = project_root()
%PROJECT_ROOT Root folder of this repository; opens the MATLAB project if needed.
%   root = PROJECT_ROOT() returns the folder of semiactive-damper-function.prj.
%   If the project is not open (e.g. MATLAB started without it, script run
%   from src/matlab), it is opened here, which also sets the MATLAB path.
%   Without this, matlab.project.rootProject() returns nothing and
%   '.RootFolder' fails with "Insufficient number of outputs from right hand
%   side of equal sign".

% This file lives in <root>/src/matlab
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
p = matlab.project.rootProject();
same = @strcmp;
if ispc
    same = @strcmpi;     % Windows paths are not case-sensitive (drive letter c or C)
end
if isempty(p) || ~same(char(p.RootFolder), root)
    fprintf('Opening MATLAB project %s\n', root);
    openProject(root);
end
end
