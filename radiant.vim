if exists('loaded_radiant')
  finish
endif



:set encoding=utf-8
ruby <<eof
RAILS_ENV='production'
require 'config/environment'

#FIXME from radiant.vim
# Find the page record
def find_page(id, parent = nil)
        r = nil
        if parent.nil?
                r = Page.find(:first, :conditions => ["parent_id IS NULL and slug like ?", id+"%" ] )
                r = Page.find(:first, :conditions => ["parent_id IS NULL and title like ?", id+"%" ] ) if r.nil?
        else
                r = parent.children.find(:first, :conditions => ["slug like ?", id+"%"])
                r = parent.children.find(:first, :conditions => ["title like ?", id+"%"]) if r.nil?
        end
        return r
end
def find_entity( entity, id)
        begin
                if id=Integer(id)
                        r = entity.find(id)
                end
        rescue Exception => e
                r =  entity.find(:all, :conditions => ["name like ?", id+"%"])
        end
        return r
end


def ReadFile(f)
        args = f.split('/')
        type = args[1]
        VIM::command('set fileencoding=utf-8')
        VIM::command('set paste')

        case type
                when 'pages'
                        requested_part = args.pop
                        parent=nil
                        args[2..args.length-1].each do |p|
                                parent = find_page(p, parent)
                        end
                        part = parent.parts.reject{|p| p.name != requested_part}[0]
                        content =  part.content
                when 'layouts'
                        requested_layout = args[2]
                        layout = find_entity(Layout, requested_layout)[0]
                        content =  layout.content
                when 'snippets'
                        requested_snippet = args[2]
                        snippet = find_entity(Snippet, requested_snippet)[0]
                        content =  snippet.content
        end

        VIM::command('1')
        VIM::command("norm i"+content)
        VIM::command('set nopaste')
        VIM::command('1')
end
def WriteFile(f)
        args = f.split('/')
        type = args[1]

        buffer = VIM::Buffer.current
  new_content = ""
  #buffer[] starts counting at 1
  buffer.count.times do |i|
                new_content+=buffer[i+1]
    new_content+="\n" if i!=buffer.count-1
        end

        case type
                when 'pages'
                        requested_part = args.pop
                        parent=nil
                        args[2..args.length].each do |p|
                                parent = find_page(p, parent)
                        end
                        part = parent.parts.reject{|p| p.name != requested_part}[0]
                        part.content=new_content
                        part.save
                        VIM::command('set nomodified')
                when 'layouts'
                        requested_layout = args[2]
                        layout = find_entity(Layout, requested_layout)[0]
                        layout.content=new_content
                        layout.save
                        VIM::command('set nomodified')
                when 'snippets'
                        requested_snippet = args[2]
                        snippet = find_entity(Snippet, requested_snippet)[0]
                        snippet.content=new_content
                        snippet.save
                        VIM::command('set nomodified')
    else
      return
    end
    #ResponseCache.instance.clear

end









eof

:command! -nargs=* -complete=customlist,RadiantCommandCompletion Radiant call RadiantCommand(<f-args>)

:fun! RadiantCommand(...)
        :ruby<<EOF
        args = VIM::evaluate("a:000").split(' ')
        command = args[0]
        path=args[1..args.length-1].join('\\ ')
        VIM::command(%{#{command} radiant/#{path}})
EOF
:endfun

:fun! RadiantCommandCompletion(ArgLead, CmdLine, CursorPos)
        let l:r=[]
        :ruby<<EOF
        arg_lead = VIM::evaluate("a:ArgLead")
        cmd_line = VIM::evaluate('a:CmdLine')
        cursor_pos = VIM::evaluate('a:CursorPos').to_i

  cmd_lead = cmd_line[0..cursor_pos]
        cmd_elements = cmd_lead.split(/\s+/)
        ex_cmd = cmd_elements[1]

  vim_commands = ["edit", "split", "vsplit"]
  if cmd_elements.length==1
    #we need to return the list of commands available
    r=vim_commands.inject("["){|s,e| s+=%{"#{e}",}}
    r=r.chop
    r+="]"
  elsif cmd_elements.length==2 and not vim_commands.include?(ex_cmd)
    r=vim_commands.reject{|c| ! c.match(%r{^#{ex_cmd}})}.inject("["){|s,e| s+=%{"#{e}",}}
    r=r.chop if r.length>1
    r+="]"
  else


    new_level = (arg_lead.last=="/") # if arg_lead's last char is /, we are starting a new level
    path= cmd_elements[2..cmd_elements.length-1].join(' ')
    path_elements = path.split('/')
    if new_level
      browse_until = -1
    else
      browse_until = -2
    end
    path_lead= path_elements[0..path_elements.length+browse_until].join('/')
    r=""
    if path_elements.length==0
        r=%{["pages","layouts","snippets"]}
    elsif (path_elements.length==1 and !new_level)
      #we need to complete the type of object we want to work on
      if "pages".match("^"+path_elements[0])
        r= %{["pages/"]}
      elsif "layouts".match("^"+path_elements[0])
        r=%{["layouts/"]}
      elsif "snippets".match("^"+path_elements[0])
        r=%{["snippets/"]}
      else
        r="[]"
      end
    else
      #we need to complete the path
      case path_elements[0]
            when "pages"
          parent=nil
          #if we have more than 2 elements or 2 elements and new level
          #eg: pages/Ho or pages/Home Page/
          if path_elements.length>2 or (path_elements.length==2 and new_level)
            parent = find_page(path_elements[1], nil)
            path_elements[2..path_elements.length+browse_until].each do |p|
              parent = find_page(p, parent)
            end
            titles = slugs = []
            #if we're at a new level, we look for all children
            if new_level
              search_string = "%"
            #if we types the start of the level, filter children accordingly
            else
              search_string =  path_elements.last+'%'
            end
            #if we have pages below the last level, look at children for completion
            if parent.children.length>0
              children = parent.children.find(:all, :conditions => ["title LIKE ?", search_string])
              titles = parent.children.find(:all, :conditions => ["title LIKE ?", search_string]).collect{|p| p.title}
              slugs = parent.children.find(:all, :conditions => ["slug LIKE ?", search_string]).collect{|p| p.slug}
            end
            #we also collect parts accordingly
            parts = parent.parts.find(:all, :conditions => [ "name like ?", search_string]).collect{|p| p.name}
            list=(titles+slugs+parts).map{|e| path_lead+"/"+e.gsub(' ','\ ') }
            list.uniq!
          #else, at the first level, it's a page we're looking for
          else
            #if it's not a new level, ie we types the start, filter accordingly
            if !new_level
              parent = find_page(path_elements[1], nil)
            #else list all
            else
              parent = find_page('', nil)
            end
            list=[]
            if parent
              list.push path_lead+"/"+parent.title.gsub(' ','\ ') if new_level or parent.title.match(%r{^#{path_elements.last}})
              list.push path_lead+"/"+parent.slug  if new_level or parent.slug.match(%r{^#{path_elements.last}})
            end
          end
          r = list.inject("["){|s,e|  s+=%{"#{e.gsub(%r{.*#{arg_lead}},arg_lead)}",}}
          r=r.chop if r.length>1
          r+="]"
        when "layouts"
          if !new_level
            layouts = find_entity(Layout, path_elements[1])
          #else list all
          else
            layouts = find_entity(Layout, "")
          end
          list= layouts.collect{|l| path_lead+"/"+l.name.gsub(' ','\ ')}
          r = list.inject("["){|s,e|  s+=%{"#{e.gsub(%r{.*#{arg_lead}},arg_lead)}",}}
          r=r.chop if r.length>1
          r+="]"
        when "snippets"
          if !new_level
            snippets = find_entity(Snippet, path_elements[1])
          #else list all
          else
            snippets = find_entity(Snippet, "")
          end
          list= snippets.collect{|l| path_lead+"/"+l.name.gsub(' ','\ ')}
          r = list.inject("["){|s,e|  s+=%{"#{e.gsub(%r{.*#{arg_lead}},arg_lead)}",}}
          r=r.chop if r.length>1
          r+="]"
      end
    end
  end
        VIM::command("let l:r=#{r}")
EOF
        return l:r
:endfun



:au BufWriteCmd radiant/* ruby WriteFile( VIM::evaluate( "expand('<afile>')"))
:au BufReadCmd radiant/* ruby ReadFile( VIM::evaluate( "expand('<afile>')"))
let loaded_radiant="yes"
