module DataMapper
  module Is
    module List

      ##
      # method for making your model a list.
      # it will define a :position property if it does not exist, so be sure to have a
      # position-column in your database (will be added automatically on auto_migrate)
      # if the column has a different name, simply make a :position-property and set a
      # custom :field
      #
      # @example [Usage]
      #   is :list  # put this in your model to make it act as a list.
      #   is :list, :scope => [:user_id] # you can also define scopes
      #   is :list, :scope => [:user_id, :context_id] # also works with multiple params
      #
      # @param options <Hash> a hash of options
      #
      # @option :scope<Array> an array of attributes that should be used to scope lists
      #
      def is_list(options={})
        options = { :scope => [], :first => 1 }.merge(options)

        extend  DataMapper::Is::List::ClassMethods
        include DataMapper::Is::List::InstanceMethods

        unless properties.any? { |p| p.name == :position && p.type == Integer }
          property :position, Integer
        end

        @list_options = options

        before :create do
          # # a position has been set before save => open up and make room for item
          # # no position has been set => move to bottom of my scope-list (or keep detached?)
          # send(:move_without_saving, position || :lowest)
          if self.position.nil?
            set_lowest_position
          end
        end

        before :update do
          if self.list_scope != self.original_list_scope
            @orig_pos = original_attributes[properties[:position]] || self.position
            @orig_scope = self.original_list_scope
            if attribute_dirty?(:position)
              @orig_old_pos = self.class.max(:position, list_scope)
            else
              set_lowest_position
            end
          end
        end
        
        after :update do
          if @orig_pos
            detach(@orig_pos, @orig_scope)
            @orig_pos = nil
            @orig_scope = nil
          end
        end
        
        before :save do
          if self.position and (not @orig_pos or @orig_old_pos)
            old_pos = @orig_old_pos || original_attributes[properties[:position]]
            new_pos = self.position
            if old_pos
              if old_pos > new_pos
                scope = list_scope
                scope[:position] = new_pos..old_pos
                self.class.all(scope).adjust!({:position => -old_pos},true)
                scope[:position] = (new_pos - old_pos)..-1
                self.class.all(scope).adjust!({:position => (old_pos + 1)},true)
                self.position = new_pos
              elsif old_pos < new_pos
                scope = list_scope
                scope[:position] = old_pos..new_pos
                self.class.all(scope).adjust!({:position => -new_pos},true)
                scope[:position] = (old_pos - new_pos + 1)..0
                self.class.all(scope).adjust!({:position => (new_pos - 1)},true)
                self.position = new_pos
              end
            end
          end
        end
        
        after :destroy do
          detach(self.position, list_scope) unless self.position.nil?
        end
        
        # we need to make sure that STI-models will inherit the list_scope.
        after_class_method :inherited do |retval, target|
          target.instance_variable_set(:@list_options, @list_options.dup)
        end
        
      end

      module ClassMethods
        attr_reader :list_options

        ##
        # use this function to repair / build your lists.
        #
        # @example [Usage]
        #   MyModel.repair_list # repairs the list, given that lists are not scoped
        #   MyModel.repair_list(:user_id => 1) # fixes the list for user 1, given that the scope is [:user_id]
        #
        # @param scope [Hash]
        #
        def repair_list(scope = {})
          return false unless scope.keys.all?{ |s| list_options[:scope].include?(s) || s == :order }
          all({ :order => [ :position ] }.merge(scope)).each_with_index{ |item, i| item.update(:position => i + 1) }
          true
        end
      end

      module InstanceMethods
        attr_accessor :moved

        def list_scope
          model.list_options[:scope].map{ |p| [ p, attribute_get(p) ] }.to_hash
        end

        def original_list_scope
          model.list_options[:scope].map{ |p| [ p, (property = properties[p]) && original_attributes.key?(property) ? original_attributes[property] : attribute_get(p) ] }.to_hash
        end

        def list_query
          list_scope.merge(:order => [ :position ])
        end

        def list(scope = list_query)
          model.all(scope)
        end

        ##
        # repair the list this item belongs to
        #
        def repair_list
          model.repair_list(list_scope)
        end

        ##
        # reorder the list this item belongs to
        #
        def reorder_list(order)
          model.repair_list(list_scope.merge(:order => order))
        end

        def detach(scope = list_scope)
          warn "deprecated - no replacement"
        end

        def left_sibling
          list.reverse.first(:position.lt => position)
        end

        def right_sibling
          list.first(:position.gt => position)
        end

        ##
        # move item to a position in the list. position should _only_ be changed through this
        #
        # @example [Usage]
        #   * node.move :higher           # moves node higher unless it is at the top of parent
        #   * node.move :lower            # moves node lower unless it is at the bottom of parent
        #   * node.move :below => other   # moves this node below other resource in the set
        #
        # @param vector <Symbol, Hash> A symbol, or a key-value pair that describes the requested movement
        #
        # @option :higher<Symbol> move item higher
        # @option :up<Symbol> move item higher
        # @option :highest<Symbol> move item to the top of the list
        # @option :lower<Symbol> move item lower
        # @option :down<Symbol> move item lower
        # @option :lowest<Symbol> move item to the bottom of the list
        # @option :above<Resource> move item above other item. must be in same scope
        # @option :below<Resource> move item below other item. must be in same scope
        # @option :to<Fixnum> move item to a specific location in the list
        #
        # @return <TrueClass, FalseClass> returns false if it cannot move to the position, otherwise true
        # @see move_without_saving
        def move(args)
          move_without_save(args) && self.dirty? && self.save
        end

       
       private
       
        def set_lowest_position
          self.position =
            if(entity = self.class.first(list_scope.merge!({:order => [:position.desc]})))
              entity.position + 1
            else
              self.class.list_options[:first]
            end
        end
        
        def detach(pos, scope)
          s = scope.dup
          s[:position.gt] = pos
          max = self.class.max(:position, s) || 0
          self.class.all(s).adjust!({:position => -1* max},true)
          scope[:position.lt] = 1
          self.class.all(scope).adjust!({:position => (max - 1)},true)
        end
        
        
        ##
        # does all the actual movement in #move, but does not save afterwards. this is used internally in
        # before :save, and will probably be marked private. should not be used by organic beings.
        #
        # @see move
        def move_without_save(args)
          if args.instance_of? Hash
            return false if args.values[0] == self or args.values[0].list_scope != self.list_scope
            case args.keys[0]
            when :above then move_above(args.values[0])
            when :below then move_below(args.values[0])
            when :to    then self.position = args.values[0]
            end
          else
            scope = list_scope
            scope[:order] = [:position]
            case args
            when :highest     then self.position = self.class.list_options[:first]
            when :lowest      then self.position = self.class.max(:position)
            when :higher,:up  then
              scope = list_scope
              if up = self.class.first(scope.merge!({:position.lt => self.position, :order => [:position.desc]}))
                move_without_save(:above => up)
              end
            when :lower,:down then
              if down = self.class.first(scope.merge!({:position.gt => self.position}))
                move_without_save(:below => down)
              end
            end
          end
          true
        end

        def move_below(item)
          if self.position > item.position
            self.position = item.position + 1
          else
            self.position = item.position
          end
        end

        def move_above(item)
          if self.position > item.position
            self.position = item.position
          else
            self.position = item.position - 1
          end
        end
        
      end # InstanceMethods
    end # List
  end # Is
end # DataMapper
