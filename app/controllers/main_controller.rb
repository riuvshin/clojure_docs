class MainController < ApplicationController

  layout 'main', :except => ["lib_search", "preview_example"]

  caches_action :quick_ref_shortdesc

  def index

    num_recent = 7
    @recently_updated = find_recently_updated(7, nil)
    @top_contributors = []

    tc_example_versions = Example.find_by_sql("select count(*), example_versions.user_id from example_versions group by user_id order by count(*) desc")[0, 10]
    tc_examples = Example.find_by_sql("select count(*), examples.user_id from examples group by user_id order by count(*) desc;")[0, 10]

    tc_examples.each do |e|
      count = e["count(*)"]
      tc_example_versions.each do |v|
        if(e.user_id == v.user_id)
          count += v["count(*)"]
        end
      end

      user = User.find(e.user_id)
      @top_contributors << {:author => user.login, :email => user.email, :score => count}
    end

  end

  def lib
    name = params[:lib]
    version = params[:version]
    
    @library = nil
    
    if version and version != 'current'
      @library = Library.find_by_url_friendly_name_and_version(name, version)
    else
      @library = Library.find_by_url_friendly_name_and_current(name, true)
    end
    
    if not @library
      logger.error "Tried to load library #{params[:lib]}"

      render :template => 'public/404.html', :layout => false, :status => 404
      return
    end
  end

  def quick_ref_shortdesc

    @library = Library.find_by_name(params[:lib])

    if @library and @library.name == "Clojure Core"
      @spheres = CCQuickRef.spheres
      render :action => "clojure_core_shortdesc"
      return
    else
      render :template => 'public/404.html', :layout => false, :status => 404
      return
    end
  end

  def quick_ref_vars_only
    @library = Library.find_by_name(params[:lib])

    if @library and @library.name == "Clojure Core"
      @spheres = CCQuickRef.spheres
      render :action => "clojure_core_vars_only"
      return
    else
      render :template => 'public/404.html', :layout => false, :status => 404
      return
    end
  end

  def libs
    @libs = Library.find(:all, :order => 'name')
  end

  def search
    q = params[:q] || ""

    @orig_query = q

    if not q.match("@library")
      q += " @library (\"Clojure Core\" | \"Clojure Contrib\")"
    end

    q = q.gsub("-", "")

    @functions = Function.search(q, :page => params[:page], :per_page => 16, :match_mode => :extended,
    :field_weights => {
      :name => 10,
      :doc => 1
      })

      if params[:feeling_lucky] and @functions.size > 0
        func = @functions[0]
        redirect_to "/#{func.library}/#{func.ns}/#{CGI::escape(func.name)}"
        return
      end


    end

    def lib_search
      q = params[:q]
      lib = params[:lib]

      res = []
      for i in (0..q.size)
        after = q[i,q.size]
        before = q[0,i]
        res << before + ".*" + after
      end

      qm = res.clone
      qm = qm.fill("?")

      sql = ""
      out = []
      if lib
        sql = "select name, ns from functions where library = ? and (name RLIKE " + qm.join(" or name RLIKE ")  + ")"   
        #      raise sql
        out = Function.find_by_sql([sql, params[:lib]] + res)
      else
        sql = "select name, ns from functions where name RLIKE " + qm.join(" or name RLIKE ")    
        out = Function.find_by_sql([sql] + res)
      end

      @functions = out.sort{|a,b| Levenshtein.distance(q, a.name) <=> Levenshtein.distance(q, b.name)}
      render :json => @functions.map{|f| {:name => f[:name], :ns => f[:ns]}}.to_json
    end

    def ns
      
      lib_name = params[:lib]
      version = params[:version]
      ns_name = params[:ns]
      
      @library = nil
      if version and version != 'current'
        @library = Library.find_by_url_friendly_name_and_version(lib_name, version)
      else
        @library = Library.find_by_url_friendly_name_and_current(lib_name, true)
      end
      
      @ns = nil 
      if version and version != 'current'
        @ns = Namespace.find_by_name_and_version(ns_name, version)
      else
        @ns = Namespace.find_by_name(ns_name)
      end
      

      if not @ns or not @library
        render :template => 'public/404.html', :layout => false, :status => 404
        return
      end
    end
    
    def function
      lib_url_name = params[:lib]
      version = params[:version]
      
      ns = params[:ns]
      function_url_name = params[:function]
      
      @library = nil
      if version and version != 'current'
        @library = Library.find_by_url_friendly_name_and_version(lib_url_name, version)
      else
        @library = Library.find_by_url_friendly_name_and_current(lib_url_name, true)
      end
      
      @ns = Namespace.find_by_name(ns)
      @function = Function.find(
        :first, 
        :conditions => {
          :library => @library.name,
          :version => @library.version,
          :ns => ns,
          :url_friendly_name => function_url_name}
          )
      
      if not @function
        logger.error "Couldn't find function id #{params[:id]}"

        render :template => 'public/404.html', :layout => false, :status => 404
        return  
      end
      
      if not @library
        logger.error "Couldn't find library by function #{@function.to_yaml}"

        render :template => 'public/404.html', :layout => false, :status => 404
        return
      end
      
      @example = Example.new
      @comment = Comment.new

      if request.post?

        if params[:update_comment]
          @comment = Comment.find(params[:comment_id])
          if @comment and @comment.user_id == current_user.id
            @comment.body = params[:comment][:body]
          end
        else
          @comment = Comment.build_from(@function, current_user.id, params[:comment][:body])
          @comment.title = params[:comment][:title]
          @comment.subject = params[:comment][:subject]
        end

        @comment.save
        redirect_to @function.href
        return


      end

    end
    
    def function_short_link
      @function = Function.find(params[:id]) rescue nil
      @library = Library.find_by_name_and_version(@function.library, @function.version)
      
      version = (params[:version] || @function.version)
      
      if not @function
        logger.error "Couldn't find function id #{params[:id]}"

        render :template => 'public/404.html', :layout => false, :status => 404
        return  
      end
      
      redirect_to :controller => 'main',
			            :action => 'function',
			            :lib => @library.url_friendly_name,
			            :version => (@library.current ? 'current' : @library.version),
			            :ns => @function.ns,
			            :function => @function.url_friendly_name
			            
    end

    def search_autocomplete
      q = params[:term]
      q = q.gsub("-", "")
      if not q
        #render :json => []
        #return
        q = ""
      end

      q = '"' + q + '*"'

      @functions = Function.search("@name #{q} @library (\"Clojure Core\" | \"Clojure Contrib\")", :field_weights => {
        :name => 100,
        :library => 1,
        :ns => 1,
        :doc => -1
        }, :match_mode => :extended)

        @functions.delete(nil)

        if @functions != nil and @functions.size > 0
          @functions.sort!{|a,b|
            aval = 0
            bval = 0

            if a.library == "Clojure Core"
              aval = 2
            elsif a.library == "Clojure Contrib"
              aval = 1
            end

            if b.library == "Clojure Core"
              bval = 2
            elsif b.library == "Clojure Contrib"
              bval = 1
            end

            bval <=> aval
          }

          @functions.sort!{|a,b| 
            Levenshtein.distance(q, a.name) <=> Levenshtein.distance(q, b.name) 
          } 
        end

        if @functions.size > 10
          @functions = @functions[0, 10]
        end

        render :json => @functions.map{|f| {:href => f.href, :ns => f.ns, :name => f.name, :examples => f.examples.size, :shortdoc => f.shortdoc }}
      end
      
      def examples_style_guide
        
      end

    end







