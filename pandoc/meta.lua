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

        local formatted_short = os.date("%m-%d", ts)
        local formatted_long = os.date("%B %e, %Y", ts)

        local this_year = os.date("%Y")

        if y ~= this_year then
            formatted_short = os.date("%y-%m-%d", ts)
        end

        meta.date_formatted = formatted_long
        date_string = formatted_short
    end

    io.write(slug_string .. "\n")
    io.write(date_string .. "\n")
    return meta
end

-- local path_utils = require 'pandoc.path'

function Link(el)
    -- If external link, open in new window and add arrow symbol
    -- Else if internal link, use target file's meta.slug or slugify title
    if string.find(el.target, "^http") then
        el.attributes.target = "_blank"
        el.content = pandoc.utils.stringify(el.content) .. "\u{2197}\u{fe0e}"
    else
        -- If link target is missing file extension, it's already a slug and can be skipped
        if el.target and not string.find(el.target, ".md") then
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
        -- local target_link_path_rel = el.target:gsub("%%20", " ")
        local target_file_path

        -- Concatenate content absolute path with link target relative path
        -- Could be pathed strangely due to absolute + relative, but should resolve
        -- Ex: $content_dir + /pages/ + /../posts/My%20Post.md
        if string.find(input_file, pages_subdir) then
            target_file_path = content_dir .. pages_subdir .. el.target
        elseif string.find(input_file, posts_subdir) then
            target_file_path = content_dir .. posts_subdir .. el.target
        else
            el = make_empty_link(el)
            return el
        end

        if target_file_path then
            target_file_path = target_file_path:gsub("%%20", " ")   -- Convert %20 to space
            target_file_path = target_file_path:gsub("[/\\]+", "/") -- Remove any double slashes

            local target_file, err = io.open(target_file_path, "r")

            -- If cannot find file, show empty link
            if err then
                el = make_empty_link(el)
                return el
            end

            local file_content = target_file:read("*all")
            local file_meta = pandoc.read(file_content).meta

            if file_meta.slug then
                target_link_slug = "/" .. pandoc.utils.stringify(file_meta.slug)
            end

            target_file:close()
        end

        el.target = target_link_slug
    end

    return el
end

-- Keep track of images so we don't lazy load the first one
local image_count = 0

function Image(img)
    -- Capture filename from (relative) image source path
    local image_filename = img.src:match("([^/\\]+)$")

    -- Prepend /images/ so image can be found within site directory
    img.src = "/images/" .. image_filename

    image_count = image_count + 1

    if image_count > 1 then
        -- Enable lazy loading and async decoding
        img.attributes.loading = "lazy"
        img.attributes.decoding = "async"
    end

    return img
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
    local filename_with_spaces = filename_no_ext:gsub("%%20", " ")

    return filename_with_spaces
end

function make_empty_link(el)
    el.target = "#"
    el.content = { pandoc.Strikeout(el.content) }
    return el
end
