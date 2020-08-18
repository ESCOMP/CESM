$(document).ready(function() {
    /* For a URL that looks like
    https://blah.github.io/versions/VERSIONFOO/html/bar/index.html, set cur_version_dir to
    'VERSIONFOO' (i.e., the portion of the path following 'versions').
    */
    var proj_end = document.baseURI.indexOf("versions") + 9;
    var end = document.baseURI.indexOf("/", proj_end);
    var cur_version_dir = document.baseURI.substring(proj_end, end);
    var mylist = $("#version-list");
    mylist.empty();
    $.getJSON(version_json_loc, function(data) {
        if (data.hasOwnProperty(cur_version_dir)) {
            /* First add the current version so that it appears first in the drop-down
               menu and starts as the selected element of the menu. If you click on the
               current version, you should stay at the current page.

               The conditional around this block should generally be true, but we check it
               just in case the current version is missing from the versions.json file for
               some reason.
            */
            cur_version_name = data[cur_version_dir];
            mylist.append($("<option>", {value: document.baseURI, text: cur_version_name}));
        }
        // Now add the other versions
        $.each(data, function(version_dir, version_name) {
            if (version_dir != cur_version_dir) {
                /* If you click on a different version, you should go to the root of the
                   documentation for that version. This assumes paths like
                   https://blah.github.io/versions/VERSIONFOO/html/bar/index.html. So we
                   need to go up two levels from the URL_ROOT (html) to then go back down
                   into the appropriate version's html directory.
                */
                mylist.append($("<option>", {value: DOCUMENTATION_OPTIONS.URL_ROOT + '../../' + version_dir + '/html', text: version_name}));
            }
        });
    });
});
