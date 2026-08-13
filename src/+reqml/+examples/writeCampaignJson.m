function writeCampaignJson(campaign_file, campaign)
%WRITECAMPAIGNJSON Write a constructed example campaign configuration.

arguments
    campaign_file {mustBeTextScalar}
    campaign (1,1) struct
end

campaign_file = string(campaign_file);
parent = string(fileparts(campaign_file));
if strlength(parent) > 0 && ~isfolder(parent)
    mkdir(parent);
end
file_id = fopen(campaign_file, "w");
if file_id < 0
    error("reqml:CannotWriteExampleCampaign", ...
        "Cannot write example campaign: %s", campaign_file);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, "%s\n", jsonencode(campaign, PrettyPrint=true));
end
