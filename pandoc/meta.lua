function Meta(meta)
    if meta.title then
        local title_string = pandoc.utils.stringify(meta.title)
        io.write(title_string .. "\n")
    end

    if meta.date then
        local date_string = pandoc.utils.stringify(meta.date)
        local y, m, d = date_string:match("(%d+)-(%d+)-(%d+)")
        local ts = os.time({ year = y, month = m, day = d })

        local formatted = os.date("%b %d", ts)
        local formatted_w_year = os.date("%b %d, %Y", ts)

        meta.date = formatted_w_year
        io.write(formatted .. "\n")
    end

    return meta
end
