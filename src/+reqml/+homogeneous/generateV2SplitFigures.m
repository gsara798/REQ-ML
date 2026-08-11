function result=generateV2SplitFigures(config_file,options)
%GENERATEV2SPLITFIGURES Visual audit of the three frozen v2 split schemes.
arguments
    config_file {mustBeTextScalar}
    options.OutputDirectory {mustBeTextScalar} = ""
end
config=jsondecode(fileread(config_file));
repo=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
root=reqml.config.resolveWorkspacePath(string(config.paths.output_root),RepositoryRoot=repo);
output=string(options.OutputDirectory); if strlength(output)==0, output=fullfile(root,"figures","split_analysis_v2"); end
if ~isfolder(output), mkdir(output); end
schemes=["in_domain","alternating_sws","alternating_angular"];
summaries=cell(numel(schemes),1); conditions=cell(numel(schemes),1);
for i=1:numel(schemes)
    folder=fullfile(root,"splits",schemes(i));
    summaries{i}=readtable(fullfile(folder,"partition_summary.csv"),TextType="string");
    conditions{i}=readtable(fullfile(folder,"condition_partitions.csv"),TextType="string");
end
paths=struct();
paths.partition_sizes=partition_sizes(summaries,schemes,output);
paths.sws_assignment=assignment_map(conditions{2},"cs_m_s","SWS (m/s)", ...
    "Alternating-SWS split",output,"b_alternating_sws_assignment");
paths.angular_assignment=assignment_map(conditions{3},"angular_level","Angular level", ...
    "Alternating-angular split",output,"c_alternating_angular_assignment");
manifest=struct("schema_name","reqml_homogeneous_q0_v2_split_figures","schema_version","1.0", ...
    "source_config",string(config_file),"paths",paths,"created_utc",string(datetime("now","TimeZone","UTC")));
write_json(fullfile(output,"figure_manifest.json"),manifest);
result=struct("paths",paths,"manifest",manifest,"output_directory",output);
end

function path=partition_sizes(parts,schemes,output)
partition_order=["train","validation","test"]; values=zeros(numel(schemes),3);
for i=1:numel(schemes)
    for j=1:3
        row=parts{i}(parts{i}.partition==partition_order(j),:); values(i,j)=row.example_count;
    end
end
display_names=replace(schemes,"_"," ");
f=new_figure(); bar(categorical(display_names,display_names),values,"stacked");
ylabel("Example count"); xlabel("Split scheme"); title("Frozen split composition");
legend(partition_order,"Location","bestoutside"); grid on;
set(gca,"TickLabelInterpreter","none");
path=save_figure(f,output,"a_partition_example_counts");
end

function path=assignment_map(t,value_name,value_label,plot_title,output,name)
values=sort(unique(double(t.(value_name)))); frequencies=sort(unique(double(t.frequency_hz)));
f=new_figure(); tiledlayout(1,3,"TileSpacing","compact","Padding","compact");
partitions=["train","validation","test"];
for p=1:3
    nexttile; counts=zeros(numel(values),numel(frequencies)); q=t(t.partition==partitions(p),:);
    for i=1:height(q)
        yi=find(values==double(q.(value_name)(i)),1); xi=find(frequencies==double(q.frequency_hz(i)),1);
        counts(yi,xi)=counts(yi,xi)+1;
    end
    imagesc(counts); axis xy; colorbar; title(partitions(p));
    xticks(1:numel(frequencies)); xticklabels(compose("%g",frequencies));
    yticks(1:numel(values)); yticklabels(compose("%g",values)); xlabel("Frequency (Hz)"); ylabel(value_label);
    set(gca,"TickLabelInterpreter","none");
end
sgtitle(plot_title);
path=save_figure(f,output,name);
end

function f=new_figure()
f=figure("Visible","off","Color","w","Position",[100 100 1200 650]);
set(f,"DefaultAxesFontName","Helvetica","DefaultAxesFontSize",11);
end

function path=save_figure(f,output,name)
path=fullfile(output,string(name)); exportgraphics(f,path+".png","Resolution",300);
exportgraphics(f,path+".pdf","ContentType","vector"); close(f);
end

function write_json(path,value)
fid=fopen(path,"w"); if fid<0, error("reqml:CannotWriteV2SplitFigures","Cannot write %s",path); end
cleanup=onCleanup(@() fclose(fid)); fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
