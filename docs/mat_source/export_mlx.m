src_dir = fullfile(pwd, 'docs', 'mat_source');
html_dir = fullfile(pwd, 'docs', 'mat_html');
fnames = {'gettingStarted.mlx'};

for i = 1:length(fnames)
    src_name = fullfile(src_dir, fnames{i});
    html_name = fullfile(html_dir, [fnames{i}(1:end - 3), 'html']);
    matlab.internal.liveeditor.openAndConvert(src_name, html_name)
end
