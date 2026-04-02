function Meta(meta)
    -- Skip index (the only page without a title)
    if not meta.title then
        return meta
    end

    local slug_string = ""
    local date_string = ""

    if meta.slug then
        slug_string = pandoc.utils.stringify(meta.slug)
    end

    if meta.date then
        local meta_date_string = pandoc.utils.stringify(meta.date)
        local y, m, d = meta_date_string:match("(%d+)-(%d+)-(%d+)")
        local ts = os.time({ year = y, month = m, day = d })

        local formatted = os.date("%b %d", ts)
        local formatted_w_year = os.date("%b %d, %Y", ts)

        meta.date = formatted_w_year
        date_string = formatted
    end

    io.write(slug_string .. "\n")
    io.write(date_string .. "\n")
    return meta
end

-- local path_utils = require 'pandoc.path'

function Link(el)
    -- If external link, open in new window and add arrow symbol
    -- Else if internal link, use slug from target file
    if string.find(el.target, "^http") then
        el.attributes.target = "_blank"
        el.content = pandoc.utils.stringify(el.content) .. "\u{2197}\u{fe0e}"
    else
        -- If link target is missing file extension, it's already a slug and can be skipped
        if not string.find(el.target, ".md") then
            return el
        end

        local home_dir = os.getenv("HOME")
        local content_dir = home_dir .. "/Documents/Notes/Natespot"

        local pages_subdir = "/pages/"
        local posts_subdir = "/posts/"

        -- Set target to slugified title as fallback if meta.slug is not found
        local target_link_filename = get_filename_from_path(el.target)
        local target_link_slug = "/" .. slugify(target_link_filename)

        local input_file = PANDOC_STATE.input_files[1]
        local target_link_path_rel = el.target:gsub("%%20", " ")
        local target_file_path

        if string.find(input_file, pages_subdir) then
            target_file_path = content_dir .. pages_subdir .. target_link_path_rel
        elseif string.find(input_file, posts_subdir) then
            target_file_path = content_dir .. posts_subdir .. target_link_path_rel
        end

        if target_file_path then
            target_file_path = target_file_path:gsub("[/\\]+", "/") -- Remove any double slashes

            local target_file, err = io.open(target_file_path, "r")

            if err then
                print("ERROR: ", err)
            end

            local file_content = target_file:read("*all")
            local file_meta = pandoc.read(file_content).meta

            if file_meta.slug then
                target_link_slug = "/" .. pandoc.utils.stringify(file_meta.slug)
            end

            target_file:close()
            -- else
            --     print(err)
        end

        el.target = target_link_slug
    end

    return el
end

function slugify(str)
    str = str:lower()
    str = str:gsub("['’]", "") -- remove apostrophes
    str = str:gsub("[^a-z0-9]+", "-") -- replace non-alphanumerics with hyphens
    str = str:gsub("^-+", ""):gsub("-+$", "") -- trim leading/trailing hyphens

    return str
end

function get_filename_from_path(path)
    local filename = pandoc.path.filename(path)
    local filename_no_ext = pandoc.path.split_extension(filename)
    local filename_with_spaces = filename:gsub("%%20", " ")

    return filename_with_spaces
end
