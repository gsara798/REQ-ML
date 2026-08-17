function actualCommit = verifyRequiredGitCommit( ...
        repositoryRoot, requiredCommit, options)
%VERIFYREQUIREDGITCOMMIT Fail unless a repository is at a required SHA.

% ActualCommit is a test seam: production callers omit it, while unit tests
% can verify mismatch handling without changing a real repository.

arguments
    repositoryRoot {mustBeTextScalar}
    requiredCommit {mustBeTextScalar}
    options.ActualCommit {mustBeTextScalar} = ""
end

repositoryRoot = string(repositoryRoot);
requiredCommit = lower(strtrim(string(requiredCommit)));
actualCommit = lower(strtrim(string(options.ActualCommit)));

if strlength(actualCommit) == 0
    command = sprintf('git -C "%s" rev-parse HEAD', repositoryRoot);
    [status, output] = system(command);
    if status ~= 0
        error("reqml:GitCommitUnavailable", ...
            "Could not resolve the Git commit for %s.", repositoryRoot);
    end
    actualCommit = lower(strtrim(string(output)));
end

if actualCommit ~= requiredCommit
    error("reqml:SimulationFrameworkCommitMismatch", ...
        ["Simulation framework HEAD is %s, but this diagnostic requires " + ...
         "%s. The repository was not changed automatically."], ...
        actualCommit, requiredCommit);
end

end
