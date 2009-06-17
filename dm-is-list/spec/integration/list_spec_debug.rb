
# Add to the ../spec_helper.rb file 
# DataMapper::Logger.new("~/dm-more.dm-is-list.specs.log", :debug)


require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

if HAS_SQLITE3 || HAS_MYSQL || HAS_POSTGRES
  describe 'DataMapper::Is::List' do
    
    class User
      include DataMapper::Resource
      
      property :id, Serial
      property :name, String
      
      has n, :todos
    end
    
    class Todo
      include DataMapper::Resource
      
      property :id,    Serial
      property :title, String
      
      belongs_to :user
      
      is :list, :scope => [:user_id]
    end
    
    before :each do
      DataMapper.logger.debug "\n ~ ========== BOOTSTRAP =="
      
      User.auto_migrate!
      Todo.auto_migrate!
      
      DataMapper.logger.debug "== END AUTOMIGRATE =="
      
      
      @u1 = User.create(:name => 'Johnny')
      DataMapper.logger.debug " "
      Todo.create(:user => @u1, :title => 'Write down what is needed in a list-plugin')
      Todo.create(:user => @u1, :title => 'Complete a temporary version of is-list')
      Todo.create(:user => @u1, :title => 'Squash any reported bugs')
      Todo.create(:user => @u1, :title => 'Make public and await public scrutiny')
      Todo.create(:user => @u1, :title => 'Rinse and repeat')
      
      DataMapper.logger.debug "== == == == == =="
      
      @u2 = User.create(:name => 'Freddy')
      DataMapper.logger.debug " "
      Todo.create(:user => @u2, :title => 'Eat tasty cupcake')
      Todo.create(:user => @u2, :title => 'Procrastinate on paid work')
      Todo.create(:user => @u2, :title => 'Go to sleep')
      
      DataMapper.logger.debug "========== END BOOTSTRAP ==\n ~ \n"
      
    end
    
    ## 
    # Keep things DRY shortcut
    #   
    #   todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
    # 
    #   todo_list(:user => @u2, :order => [:id]).should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
    # 
    def todo_list(options={})
      options = { :user => @u1, :order => [:position] }.merge(options)
      Todo.all(:user => options[:user], :order => options[:order]).map{ |a| [a.id, a.position] }
    end
    
    describe "Class Methods" do 
      
      describe "#repair_list" do 
        
        it "should repair a scoped list" do 
          DataMapper.logger.debug "Class Methods => #repair_list => scoped"
          DataMapper.repository(:default) do |repos|
            items = Todo.all(:user => @u1, :order => [:position])
            items.each{ |item| item.update(:position => [4,2,8,32,16][item.id - 1]) }
            
            todo_list.should == [ [2, 2], [1, 4], [3, 8], [5, 16], [4, 32] ]
            
            Todo.repair_list(:user_id => @u1.id)
            
            todo_list.should == [ [2, 1], [1, 2], [3, 3], [5, 4], [4, 5] ]
          end
          DataMapper.logger.debug "Class Methods => #repair_list => scoped"
          
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          
          # ~ (0.000025) UPDATE "todos" SET "position" = 4 WHERE "id" = 1
          # ~ (0.000024) UPDATE "todos" SET "position" = 8 WHERE "id" = 3
          # ~ (0.000026) UPDATE "todos" SET "position" = 32 WHERE "id" = 4
          # ~ (0.000024) UPDATE "todos" SET "position" = 16 WHERE "id" = 5
          
          # ~ (0.000028) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          
          # ~ (0.000027) UPDATE "todos" SET "position" = 1 WHERE "id" = 2
          # ~ (0.000026) UPDATE "todos" SET "position" = 2 WHERE "id" = 1
          # ~ (0.000030) UPDATE "todos" SET "position" = 3 WHERE "id" = 3
          # ~ (0.000024) UPDATE "todos" SET "position" = 4 WHERE "id" = 5
          # ~ (0.000024) UPDATE "todos" SET "position" = 5 WHERE "id" = 4
          
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          
        end
        
        it "should repair unscoped lists" do 
          DataMapper.logger.debug "Class Methods => #repair_list => un-scoped"
          DataMapper.repository(:default) do |repos|
            Todo.all.map { |t| [t.id, t.position] }.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 1], [7, 2], [8, 3] ]
            
            Todo.repair_list
            
            # note the order, repairs lists based on position
            Todo.all.map { |t| [t.id, t.position] }.should == [ [1, 1], [2, 3], [3, 5], [4, 7], [5, 8], [6, 2], [7, 4], [8, 6] ] 
            Todo.all(:order => [:position]).map { |t| t.id }.should == [1, 6, 2, 7, 3, 8, 4, 5]
          end
          DataMapper.logger.debug "Class Methods => #repair_list => un-scoped"
          
          # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" ORDER BY "id"
          
          # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" ORDER BY "position"
          # ~ (0.000025) UPDATE "todos" SET "position" = 2 WHERE "id" = 6
          # ~ (0.000024) UPDATE "todos" SET "position" = 3 WHERE "id" = 2
          # ~ (0.000024) UPDATE "todos" SET "position" = 4 WHERE "id" = 7
          # ~ (0.000024) UPDATE "todos" SET "position" = 5 WHERE "id" = 3
          # ~ (0.000023) UPDATE "todos" SET "position" = 6 WHERE "id" = 8
          # ~ (0.000023) UPDATE "todos" SET "position" = 7 WHERE "id" = 4
          # ~ (0.000024) UPDATE "todos" SET "position" = 8 WHERE "id" = 5
          
          # ~ (0.000020) SELECT "id", "title", "position", "user_id" FROM "todos" ORDER BY "id"
          
          # ~ (0.000020) SELECT "id", "title", "position", "user_id" FROM "todos" ORDER BY "position"
          
        end
        
      end #/ #repair_list
      
    end #/ Class Methods
    
    describe "Instance Methods" do 
      
      describe "#move" do 
        
        describe ":higher" do 
          
          it "should move item :higher in list" do 
            DataMapper.logger.debug ":higher => should move item :higher in list"
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(:higher).should == true
              todo_list.should == [ [2, 1], [1, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug "/:higher => should move item :higher in list"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
            
            # ~ (0.000029) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            
            # ~ (0.000037) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (2, 5) AND "position" BETWEEN 1 AND 2 ORDER BY "position"
            # ~ (0.000044) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 2
            # ~ (0.000017) SELECT "id", "position" FROM "todos" WHERE "id" = 2
            # ~ (0.000024) UPDATE "todos" SET "position" = 1 WHERE "id" = 2
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
            
            # ~ (0.000028) SELECT "id", "parent_id", "name", "position" FROM "albums" WHERE "id" = 2
            
            # ~ (0.000031) SELECT "id", "parent_id", "name", "position" FROM "albums" WHERE "parent_id" = 0 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000055) UPDATE "albums" SET "position" = "position" + 1 WHERE "parent_id" = 0 AND "position" BETWEEN 1 AND 2
            # ~ (0.000035) UPDATE "albums" SET "position" = 1 WHERE "id" = 2
            
            # ~ (0.000037) SELECT "id", "parent_id", "name", "position" FROM "albums" WHERE "parent_id" = 0 ORDER BY "position"
            
          end
          
          it "should NOT move item :higher when first in list" do 
            DataMapper.logger.debug ":higher => should NOT move item :higher when first in list"
            DataMapper.repository(:default) do |repos|
              Todo.get(1).move(:higher).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug "/:higher => should NOT move item :higher when first in list"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 1
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          end
          
        end #/ :higher
        
        describe ":lower" do 
          
          it "should move item :lower in list" do 
            DataMapper.logger.debug ":lower => should move item :lower in list"
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(:lower).should == true
              todo_list.should == [ [1, 1], [3, 2], [2, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":lower => should move item :lower in list"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
            
            # ~ (0.000030) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000037) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (2, 5) AND "position" BETWEEN 2 AND 3 ORDER BY "position"
            # ~ (0.000045) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 2 AND 3
            # ~ (0.000017) SELECT "id", "position" FROM "todos" WHERE "id" = 2
            # ~ (0.000024) UPDATE "todos" SET "position" = 3 WHERE "id" = 2
            
            # ~ (0.000060) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should NOT move item :lower when last in list" do 
            DataMapper.logger.debug ":lower => should NOT move item :lower when last in list"
            DataMapper.repository(:default) do |repos|
              Todo.get(5).move(:lower).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":lower => should NOT move item :lower when last in list"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 5
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
        end #/ :lower
        
        describe ":up" do 
          
          it "should move item :up in list" do 
            DataMapper.logger.debug ":up => should move item :up in list"
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(:up).should == true
              todo_list.should == [ [2, 1], [1, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":up => should move item :up in list"
            
            # ~ (0.000020) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
            
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000035) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (2, 5) AND "position" BETWEEN 1 AND 2 ORDER BY "position"
            # ~ (0.000045) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 2
            # ~ (0.000018) SELECT "id", "position" FROM "todos" WHERE "id" = 2
            # ~ (0.000024) UPDATE "todos" SET "position" = 1 WHERE "id" = 2
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should NOT move item :up when first in list" do 
            DataMapper.logger.debug ":up => should NOT move item :up when first in list"
            DataMapper.repository(:default) do |repos|
              Todo.get(1).move(:up).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":up => should NOT move item :up when first in list"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 1
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000022) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
        end #/ :up
        
        describe ":down" do 
          
          it "should move item :down in list" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(:down).should == true
              todo_list.should == [ [1, 1], [3, 2], [2, 3], [4, 4], [5, 5] ]
            end
          end
          
          it "should NOT move :down when last in list" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(5).move(:down).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
          end
          
        end #/ :down
        
        describe ":top" do 
          
          it "should move item to :top of list" do 
            DataMapper.logger.debug ":top => should move item to :top of list"
            DataMapper.repository(:default) do |repos|
              Todo.get(5).move(:top).should == true
              todo_list.should == [ [5, 1], [1, 2], [2, 3], [3, 4], [4, 5] ]
            end
            DataMapper.logger.debug ":top => should move item to :top of list"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 5
            
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000025) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" = 5 AND "position" BETWEEN 1 AND 5
            # ~ (0.000046) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 5
            # ~ (0.000017) SELECT "id", "position" FROM "todos" WHERE "id" = 5
            # ~ (0.000025) UPDATE "todos" SET "position" = 1 WHERE "id" = 5
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should NOT move item to :top of list when it is already first" do 
            DataMapper.logger.debug ":top => should NOT move item to :top of list when it is already first"
            DataMapper.repository(:default) do |repos|
              Todo.get(1).move(:top).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":top => should NOT move item to :top of list when it is already first"
          end
          
        end #/ :top
        
        describe ":bottom" do 
          
          it "should move item to :bottom of list" do 
            DataMapper.logger.debug ":bottom => should move item to :bottom of list"
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(:bottom).should == true
              todo_list.should == [ [1, 1], [3, 2], [4, 3], [5, 4], [2, 5] ]
            end
            DataMapper.logger.debug ":bottom => should move item to :bottom of list"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
            
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000032) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (2, 5) AND "position" BETWEEN 2 AND 5 ORDER BY "position"
            # ~ (0.000046) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 2 AND 5
            # ~ (0.000023) SELECT "id", "position" FROM "todos" WHERE "id" IN (2, 5) ORDER BY "id"
            # ~ (0.000028) UPDATE "todos" SET "position" = 5 WHERE "id" = 2
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should NOT move item to :bottom of list when it is already last" do 
            DataMapper.logger.debug ":bottom => should NOT move item to :bottom of list when it is already last"
            DataMapper.repository(:default) do |repos|
              Todo.get(5).move(:bottom).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":bottom => should NOT move item to :bottom of list when it is already last"
          end
          
        end #/ :bottom
        
        describe ":highest" do 
          
          it "should move item :highest in list" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(5).move(:highest).should == true
              todo_list.should == [ [5, 1], [1, 2], [2, 3], [3, 4], [4, 5] ]
            end
          end
          
          it "should NOT move item :highest in list when it is already first" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(1).move(:highest).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
          end
          
        end #/ :highest
        
        describe ":lowest" do 
          
          it "should move item :lowest in list" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(:lowest).should == true
              todo_list.should == [ [1, 1], [3, 2], [4, 3], [5, 4], [2, 5] ]
            end
          end
          
          it "should NOT move item :lowest in list when it is already last" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(5).move(:lowest).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
          end
          
        end #/ :lowest
        
        describe ":above" do 
          
          it "should move item :above another in list" do 
            DataMapper.logger.debug ":above => should move item :above another in list"
            DataMapper.repository(:default) do |repos|
              Todo.get(3).move(:above => Todo.get(2) ).should == true
              todo_list.should == [ [1, 1], [3, 2], [2, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":above => should move item :above another in list"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 3
            # ~ (0.000018) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
            
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000033) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (2, 3, 5) AND "position" BETWEEN 2 AND 3 ORDER BY "position"
            # ~ (0.000049) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 1 AND "position" BETWEEN 2 AND 3
            # ~ (0.000023) SELECT "id", "position" FROM "todos" WHERE "id" IN (2, 3) ORDER BY "id"
            # ~ (0.000025) UPDATE "todos" SET "position" = 2 WHERE "id" = 3
            
            # ~ (0.000028) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should NOT move item :above itself" do 
            DataMapper.logger.debug ":above => should NOT move item :above itself"
            DataMapper.repository(:default) do |repos|
              Todo.get(1).move(:above => Todo.get(1) ).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":above => should NOT move item :above itself"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 1
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should NOT move item :above a lower item (it's already above)" do 
            DataMapper.logger.debug ":above => should NOT move item :above a lower item (it's already above)"
            DataMapper.repository(:default) do |repos|
              Todo.get(1).move(:above => Todo.get(2) ).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":above => should NOT move item :above a lower item (it's already above)"
            
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 1
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should NOT move the item :above another item in a different scope" do 
            DataMapper.logger.debug ":above => should NOT move the item :above another item in a different scope"
            DataMapper.repository(:default) do |repos|
              Todo.get(1).move(:above => Todo.get(6) ).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":above => should NOT move the item :above another item in a different scope"
            
            # ~ (0.000020) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 1
            # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 6
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
        end #/ :above
        
        describe ":below" do 
          
          it "should move item :below another in list" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(:below => Todo.get(3) ).should == true
              todo_list.should == [ [1, 1], [3, 2], [2, 3], [4, 4], [5, 5] ]
            end
          end
          
          it "should NOT move item :below itself" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(1).move(:below => Todo.get(1) ).should == false  # is this logical ???
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
          end
          
          it "should NOT move item :below a higher item (it's already below)" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(5).move(:below => Todo.get(4) ).should == false  # is this logical ???
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
          end
          
          it "should NOT move the item :below another item in a different scope" do 
            DataMapper.logger.debug ":below => should NOT move the item :below another item in a different scope"
            DataMapper.repository(:default) do |repos|
              Todo.get(1).move(:below => Todo.get(6) ).should == false
              todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            end
            DataMapper.logger.debug ":below => should NOT move the item :below another item in a different scope"
            
            # ~ (0.000018) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 1
            # ~ (0.000018) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 6
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          
        end #/ :below
        
        describe ":to" do 
          
          describe "=> FixNum" do 
            
            it "should move item to the position" do 
              DataMapper.logger.debug ":to => FixNum ==="
              DataMapper.repository(:default) do |repos|
                Todo.get(2).move(:to => 3 ).should == true
                todo_list.should == [ [1, 1], [3, 2], [2, 3], [4, 4], [5, 5] ]
              end
              DataMapper.logger.debug ":to => FixNum ==="
              
              # ~ (0.000020) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
              
              # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
              # ~ (0.000032) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (2, 5) AND "position" BETWEEN 2 AND 3 ORDER BY "position"
              # ~ (0.000045) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 2 AND 3
              # ~ (0.000017) SELECT "id", "position" FROM "todos" WHERE "id" = 2
              # ~ (0.000025) UPDATE "todos" SET "position" = 3 WHERE "id" = 2
              
              # ~ (0.000022) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
              
            end
            
            it "should NOT move item to a position above the first item in list (negative position)" do 
              DataMapper.repository(:default) do |repos|
                Todo.get(2).move(:to => -33 ).should == true
                todo_list.should == [ [2, 1], [1, 2], [3, 3], [4, 4], [5, 5] ]
              end
            end
            
            it "should NOT move item to a position below the last item in list (out of range - position)" do 
              DataMapper.repository(:default) do |repos|
                Todo.get(2).move(:to => 33 ).should == true
                todo_list.should == [ [1, 1], [3, 2], [4, 3], [5, 4], [2, 5] ]
              end
            end
            
          end #/ => FixNum
          
          describe "=> String" do 
            
            it "should move item to the position" do 
              DataMapper.repository(:default) do |repos|
                Todo.get(2).move(:to => '3' ).should == true
                todo_list.should == [ [1, 1], [3, 2], [2, 3], [4, 4], [5, 5] ]
              end
            end
            
            it "should NOT move item to a position above the first item in list (negative position)" do 
              DataMapper.repository(:default) do |repos|
                Todo.get(2).move(:to => '-33' ).should == true
                todo_list.should == [ [2, 1], [1, 2], [3, 3], [4, 4], [5, 5] ]
              end
            end
            
            it "should NOT move item to a position below the last item in list (out of range - position)" do 
              DataMapper.repository(:default) do |repos|
                Todo.get(2).move(:to => '33' ).should == true
                todo_list.should == [ [1, 1], [3, 2], [4, 3], [5, 4], [2, 5] ]
              end
            end
            
          end #/ => String
          
        end #/ :to
        
        describe "X  (position as Integer)" do 
          
          it "should move item to the position" do 
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(3).should == true
              todo_list.should == [ [1, 1], [3, 2], [2, 3], [4, 4], [5, 5] ]
            end
          end
          
          it "should move the same item to different positions multiple times" do 
            DataMapper.repository(:default) do |repos|
              item = Todo.get(2)
              
              item.move(3).should == true
              todo_list.should == [ [1, 1], [3, 2], [2, 3], [4, 4], [5, 5] ]
              
              item.move(1).should == true
              todo_list.should == [ [2, 1], [1, 2], [3, 3], [4, 4], [5, 5] ]
            end
          end
          
          it 'should NOT move item to a position above the first item in list (negative position)' do 
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(-33).should == true
              todo_list.should == [ [2, 1], [1, 2], [3, 3], [4, 4], [5, 5] ]
            end
          end
          
          it 'should NOT move item to a position below the last item in list (out of range - position)' do 
            DataMapper.repository(:default) do |repos|
              Todo.get(2).move(33).should == true
              todo_list.should == [ [1, 1], [3, 2], [4, 3], [5, 4], [2, 5] ]
            end
          end
          
        end #/ #move(X)
        
        describe "#move(:non_existant_vector_symbol)" do 
          
          it "should raise an ArgumentError when given an un-recognised symbol value" do 
            DataMapper.repository(:default) do |repos|
              lambda { Todo.get(2).move(:non_existant_vector_symbol) }.should raise_error(ArgumentError)
            end
          end
          
        end #/ #move(:non_existant_vector)
        
      end #/ #move
      
      describe "#list_scope" do 
        
        describe 'with no scope' do 
          class Property
            include DataMapper::Resource
            
            property :id, Serial
            
            is :list
          end
          
          before do
            @property = Property.new
          end
          
          it 'should return an empty hash' do
            @property.list_scope.should == {}
          end
          
        end
        
        describe 'with a scope' do 
          
          it 'should know the scope of the list the item belongs to' do
            Todo.get(1).list_scope.should == {:user_id => @u1.id }
          end
          
        end
        
      end #/ #list_scope
      
      describe "#original_list_scope" do 
        
        it 'should know the original list scope after the scope changes' do
          item = Todo.get(2)
          item.user = @u2
          
          item.original_list_scope.should == {:user_id => @u1.id }
        end
        
      end #/ #original_list_scope
      
      describe "#list_query" do 
        
        it 'should return a hash with conditions to get the entire list this item belongs to' do
          Todo.get(2).list_query.should == { :user_id => @u1.id, :order => [:position] }
        end
        
      end #/ #list_query
      
      describe "#list" do 
        
        it "should return all list items in the current list item's scope" do 
          DataMapper.logger.debug "should return all list items in the current list item's scope"
          DataMapper.repository(:default) do |repos|
            Todo.get(2).list.should == Todo.all(:user => @u1)
          end
          DataMapper.logger.debug "should return all list items in the current list item's scope"
        end
        
        it "should return all items in the specified scope" do 
          DataMapper.logger.debug "should return all items in the specified scope"
          DataMapper.repository(:default) do |repos|
            Todo.get(2).list(:user => @u2 ).should == Todo.all(:user => @u2)
          end
          DataMapper.logger.debug "should return all items in the specified scope"
        end
        
      end #/ #list
      
      describe "#repair_list" do 
        
        it 'should repair the list positions after a manually updated position' do 
          DataMapper.repository(:default) do |repos|
            item = Todo.get(5)
            item.update(:position => 20)
            item.position.should == 20
            
            todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 20] ]
            
            item = Todo.get(5)
            item.repair_list
            item.position.should == 5
          end
        end
        
      end #/ #repair_list
      
      describe "#reorder_list" do 
        
        before do
          @u3 = User.create(:name => 'Eve')
          @todo_1 = Todo.create(:user => @u3, :title => "Clean the house")
          @todo_2 = Todo.create(:user => @u3, :title => "Brush the dogs")
          @todo_3 = Todo.create(:user => @u3, :title => "Arrange bookshelf")
        end
        
        it "should description" do 
          DataMapper.logger.debug "#reorder_list =>  should..."
          DataMapper.repository(:default) do |repos|
            todo_list(:user => @u3).should == [ [9, 1], [10, 2], [11, 3] ]
            
            @todo_1.reorder_list([:title.asc]).should == true
            
            todo_list(:user => @u3).should == [ [11, 1], [10, 2], [9, 3] ]
          end
          DataMapper.logger.debug "#reorder_list =>  should..."
          
          # ~ (0.000022) INSERT INTO "users" ("name") VALUES ('Eve')
          
          # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 3 ORDER BY "position" DESC LIMIT 1
          # ~ (0.000029) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 3 AND "position" >= 1
          # ~ (0.000030) INSERT INTO "todos" ("title", "position", "user_id") VALUES ('Clean the house', 1, 3)
          # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 3 ORDER BY "position" DESC LIMIT 1
          # ~ (0.000030) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 3 AND "position" >= 2
          # ~ (0.000032) INSERT INTO "todos" ("title", "position", "user_id") VALUES ('Brush the dogs', 2, 3)
          # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 3 ORDER BY "position" DESC LIMIT 1
          # ~ (0.000030) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 3 AND "position" >= 3
          # ~ (0.000031) INSERT INTO "todos" ("title", "position", "user_id") VALUES ('Arrange bookshelf', 3, 3)
          
          # ~ #reorder_list =>  should...
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 3 ORDER BY "title"
          # ~ (0.000026) UPDATE "todos" SET "position" = 1 WHERE "id" = 11
          # ~ (0.000025) UPDATE "todos" SET "position" = 3 WHERE "id" = 9
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 3 ORDER BY "position"
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 3 ORDER BY "title"
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 3 ORDER BY "position"
          # ~ #reorder_list =>  should...
          
        end
        
      end #/ #reorder_list
      
      describe "#detach" do 
        
        it 'should detach from old list if scope is changed and retain position in new list' do
          DataMapper.logger.debug "should detach from old list if scope changed =================="
          DataMapper.repository(:default) do |repos| 
            item = Todo.get(2) 
            item.position.should == 2
            item.user.should == @u1
            
            item.user = @u2
            item.save
            
            item.list_scope.should != item.original_list_scope
            item.list_scope.should == { :user_id => @u2.id }
            item.position.should == 2
            
            todo_list.should == [[1, 1], [3, 2], [4, 3], [5, 4]]
            
            todo_list(:user => @u2).should == [[6, 1], [2, 2], [7, 3], [8, 4]]
            
          end
          DataMapper.logger.debug "should detach from old list if scope changed =================="
          
          # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
          
          # ~ (0.000020) SELECT "id", "name" FROM "users" WHERE "id" = 1 ORDER BY "id" LIMIT 1
          # ~ (0.000020) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" = 2 AND "position" > 2
          # ~ (0.000039) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" > 2
          # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 2 ORDER BY "position" DESC LIMIT 1
          # ~ (0.000027) SELECT "id" FROM "todos" WHERE "user_id" = 2 AND "id" IN (2, 8) AND "position" >= 2 ORDER BY "position"
          # ~ (0.000037) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 2 AND "position" >= 2
          # ~ (0.000017) SELECT "id", "position" FROM "todos" WHERE "id" = 8
          # ~ (0.000030) UPDATE "todos" SET "position" = 2, "user_id" = 2 WHERE "id" = 2
          
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 2 ORDER BY "position"
          
        end
        
        it 'should detach from old list if scope is changed and given bottom position in new list if position is empty' do
          DataMapper.logger.debug "should detach from old list if scope changed =================="
          DataMapper.repository(:default) do |repos| 
            item = Todo.get(2) 
            item.position.should == 2
            item.user.should == @u1
            
            item.position = nil  #  NOTE:: Creates a messed up original list.
            item.user = @u2
            item.save
            
            item.list_scope.should != item.original_list_scope
            item.list_scope.should == { :user_id => @u2.id }
            item.position.should == 4
            
            
            todo_list.should == [ [1, 1], [3, 3], [4, 4], [5, 5] ]
            
            todo_list(:user => @u2).should == [ [6, 1], [7, 2], [8, 3], [2, 4] ]
            
          end
          DataMapper.logger.debug "should detach from old list if scope changed =================="
          
          # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
          
          # ~ (0.000020) SELECT "id", "name" FROM "users" WHERE "id" = 1 ORDER BY "id" LIMIT 1
          # ~ (0.000020) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" = 2 AND "position" > 2
          # ~ (0.000039) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" > 2
          # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 2 ORDER BY "position" DESC LIMIT 1
          # ~ (0.000027) SELECT "id" FROM "todos" WHERE "user_id" = 2 AND "id" IN (2, 8) AND "position" >= 2 ORDER BY "position"
          # ~ (0.000037) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 2 AND "position" >= 2
          # ~ (0.000017) SELECT "id", "position" FROM "todos" WHERE "id" = 8
          # ~ (0.000030) UPDATE "todos" SET "position" = 2, "user_id" = 2 WHERE "id" = 2
          
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 2 ORDER BY "position"
          
        end
        
      end #/ #detach
      
      describe "#left_sibling (alias #higher_item)" do 
        
        it "should return the next higher item in list" do 
          DataMapper.repository(:default) do |repos|
            item = Todo.get(2)
            item.left_sibling.should == Todo.get(1)
            item.higher_item.should == Todo.get(1)
          end
        end
        
        it "should return nil when there's NO higher item" do 
          DataMapper.repository(:default) do |repos|
            item = Todo.get(1)
            item.left_sibling.should == nil
            item.higher_item.should == nil
          end
        end
        
      end #/ #left_sibling (alias #higher_item)
      
      describe "#right_sibling (alias #lower_item)" do 
        
        it "should return the next lower item in list" do 
          DataMapper.repository(:default) do |repos|
            item = Todo.get(2)
            item.right_sibling.should == Todo.get(3)
            item.lower_item.should == Todo.get(3)
          end
        end
        
        it "should return nil when there's NO lower item" do 
          DataMapper.repository(:default) do |repos|
            item = Todo.get(5)
            item.right_sibling.should == nil
            item.lower_item.should == nil
          end
        end
        
      end #/ #right_sibling (alias #lower_item)
      
    end #/ Instance Methods
    
    describe "Workflows" do 
      
      describe "CRUD" do 
        
        # describe "#create" do 
        #   
        # end #/ #create
        
        describe "Updating list items" do 
          
          it "should NOT loose position when updating other attributes" do 
            DataMapper.logger.debug "should NOT loose position when updating =================="
            DataMapper.repository(:default) do |repos| 
              item = Todo.get(2) 
              item.position.should == 2
              item.user.should == @u1
              
              item.update(:title => "Updated")
              
              item = Todo.get(2)
              item.position.should == 2
              item.title.should == 'Updated'
              item.user.should == @u1
              
            end
            DataMapper.logger.debug "should NOT loose position when updating =================="
            
          end
          
        end #/ Updating list items
        
        describe "Deleting items" do 
          
          describe "using #destroy" do 
            
            it 'should detach from list and list should automatically repair positions' do
              DataMapper.logger.debug "should detach from list when deleted =================="
              DataMapper.repository(:default) do |repos|
                todo_list.should == [[1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
                Todo.get(2).destroy.should == true
                todo_list.should == [[1, 1], [3, 2], [4, 3], [5, 4] ]
              end
              DataMapper.logger.debug "should detach from list when deleted =================="
            end
            
          end #/ using #destroy
          
          describe "using #destroy!" do 
            
            it 'should detach from list when deleted and list should NOT automatically repair positions when using #destroy!' do
              DataMapper.logger.debug "should detach from list when deleted =================="
              DataMapper.repository(:default) do |repos|
                todo_list.should == [[1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
                Todo.get(2).destroy!.should == true
                todo_list.should == [[1, 1], [3, 3], [4, 4], [5, 5] ]
              end
              DataMapper.logger.debug "should detach from list when deleted =================="
            end
            
          end #/ using #destroy!
          
        end #/ Deleting items
        
      end #/ CRUD
      
      describe 'Automatic positioning' do 
        
        it 'should get the shadow variable of the last position' do 
          DataMapper.logger.debug "should get the shadow variable of the last position =================="
          DataMapper.repository do
            Todo.get(3).position = 8
            Todo.get(3).should be_dirty
            Todo.get(3).attribute_dirty?(:position).should == true
            Todo.get(3).original_attributes[ Todo.properties[:position] ].should == 3
            Todo.get(3).list_scope.should == Todo.get(3).original_list_scope
          end
          DataMapper.logger.debug "should get the shadow variable of the last position =================="
          
          # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 3
          
        end
        
        it 'should insert items into the list automatically on create' do 
          DataMapper.logger.debug "should insert items into the list automatically =================="
          DataMapper.repository(:default) do |repos|
            todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            todo_list(:user => @u2).should == [ [6, 1], [7, 2], [8, 3] ]
          end
          DataMapper.logger.debug "should insert items into the list automatically =================="
          
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 2 ORDER BY "position"
          
        end
        
        it 'should NOT rearrange items when setting position manually' do 
          # NOTE:: The positions in the list does NOT change automatically when an item is given
          # a position via this syntax:
          #   
          #   item.position = 4
          #   item.save
          # 
          # Enabling this functionality (re-shuffling list on update) causes a lot of extra SQL queries
          # and ultimately still get the list order wrong when doing a batch update.
          # 
          # This 'breakes' the common assumption of updating an item variable, but I think it's a worthwhile break
          
          DataMapper.logger.debug "should NOT rearrange items when setting position yourself =================="
          DataMapper.repository(:default) do |repos|
            item = Todo.get(2)
            item.position = 1
            item.save
            
            #  NOTE:: does not change the positions of the other items in the list 
            todo_list.should == [ [1, 1], [2, 1], [3, 3], [4, 4], [5, 5] ]
          end
          DataMapper.logger.debug "should NOT rearrange items when setting position yourself =================="
          
          # ~ (0.000020) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 2
          # ~ (0.000025) UPDATE "todos" SET "position" = 1 WHERE "id" = 2
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          
        end
        
      end # automatic positioning
      
      describe "Batch change item positions" do 
        
        describe "when using item.position = N syntax " do 
          
          it "should reverse the list" do 
            DataMapper.logger.debug "manually reorder positions should reverse list =================="
            DataMapper.repository(:default) do |repos|
              items = Todo.all(:user => @u1, :order => [:position])
              
              items.each{ |item| item.update(:position => [5,4,3,2,1].index(item.id) + 1) }
              
              todo_list.should == [ [5,1], [4,2], [3,3], [2,4], [1,5] ]
            end
            DataMapper.logger.debug "manually reorder positions should reverse list =================="
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
            # ~ (0.000027) UPDATE "todos" SET "position" = 5 WHERE "id" = 1
            # ~ (0.000025) UPDATE "todos" SET "position" = 4 WHERE "id" = 2
            # ~ (0.000025) UPDATE "todos" SET "position" = 2 WHERE "id" = 4
            # ~ (0.000026) UPDATE "todos" SET "position" = 1 WHERE "id" = 5
            
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should move the first item to last in list" do 
            DataMapper.logger.debug "manually reorder positions should move first last=================="
            DataMapper.repository(:default) do |repos|
              items = Todo.all(:user => @u1, :order => [:position])
              
              items.each{ |item| item.update(:position => [2,3,4,5,1].index(item.id) + 1) }
              
              todo_list.should == [ [2,1], [3,2], [4,3], [5,4], [1,5] ]
            end
            DataMapper.logger.debug "manually reorder positions should move first last =================="
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
            # ~ (0.000025) UPDATE "todos" SET "position" = 5 WHERE "id" = 1
            # ~ (0.000024) UPDATE "todos" SET "position" = 1 WHERE "id" = 2
            # ~ (0.000024) UPDATE "todos" SET "position" = 2 WHERE "id" = 3
            # ~ (0.000024) UPDATE "todos" SET "position" = 3 WHERE "id" = 4
            # ~ (0.000024) UPDATE "todos" SET "position" = 4 WHERE "id" = 5
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should randomly move items around in the list" do 
            DataMapper.logger.debug "when using item.position = N => should randomly move items around in the list =================="
            DataMapper.repository(:default) do |repos|
              items = Todo.all(:user => @u1, :order => [:position])
              
              items.each{ |item| item.update(:position => [5,2,4,3,1].index(item.id) + 1) }
              
              todo_list.should == [ [5,1], [2,2], [4,3], [3,4], [1,5] ]
            end
            DataMapper.logger.debug "when using item.position = N => should randomly move items around in the list =================="
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
            # ~ (0.000025) UPDATE "todos" SET "position" = 5 WHERE "id" = 1
            # ~ (0.000024) UPDATE "todos" SET "position" = 4 WHERE "id" = 3
            # ~ (0.000024) UPDATE "todos" SET "position" = 3 WHERE "id" = 4
            # ~ (0.000055) UPDATE "todos" SET "position" = 1 WHERE "id" = 5
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
        end #/ when using item.position = N syntax
        
        describe "when using item.move(N) syntax => [NB! create more SQL queries]" do 
          
          it "should reverse the list => [NB! creates 5x the number of SQL queries]" do 
            DataMapper.logger.debug "should reverse the list with #move(n) =================="
            DataMapper.repository(:default) do |repos|
              items = Todo.all(:user => @u1, :order => [:position])
              
              items.each{ |item| item.move([5,4,3,2,1].index(item.id) + 1) }
              
              todo_list.should == [ [5,1], [4,2], [3,3], [2,4], [1,5] ]
            end
            DataMapper.logger.debug "should reverse the list with #move(n) =================="
            
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1          
            # ~ (0.000036) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 1 AND 5 ORDER BY "position"
            # ~ (0.000049) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 5
            # ~ (0.000025) SELECT "id", "position" FROM "todos" WHERE "id" IN (1, 2, 3, 4, 5) ORDER BY "id"
            # ~ (0.000026) UPDATE "todos" SET "position" = 5 WHERE "id" = 1
            
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000036) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 1 AND 4 ORDER BY "position"
            # ~ (0.000048) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 4
            # ~ (0.000025) SELECT "id", "position" FROM "todos" WHERE "id" IN (2, 3, 4, 5) ORDER BY "id"
            # ~ (0.000026) UPDATE "todos" SET "position" = 4 WHERE "id" = 2
            
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000035) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 1 AND 3 ORDER BY "position"
            # ~ (0.000046) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 3
            # ~ (0.000024) SELECT "id", "position" FROM "todos" WHERE "id" IN (3, 4, 5) ORDER BY "id"
            # ~ (0.000028) UPDATE "todos" SET "position" = 3 WHERE "id" = 3
            
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000036) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 1 AND 2 ORDER BY "position"
            # ~ (0.000044) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 2
            # ~ (0.000023) SELECT "id", "position" FROM "todos" WHERE "id" IN (4, 5) ORDER BY "id"
            # ~ (0.000026) UPDATE "todos" SET "position" = 2 WHERE "id" = 4
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should move the first item to last in list" do 
            DataMapper.logger.debug "when using item.move(N) => should move the first item to last in list =================="
            DataMapper.repository(:default) do |repos|
              items = Todo.all(:user => @u1, :order => [:position])
              
              items.each{ |item| item.move([2,3,4,5,1].index(item.id) + 1) }
              
              todo_list.should == [ [2,1], [3,2], [4,3], [5,4], [1,5] ]
            end
            DataMapper.logger.debug "when using item.move(N) => should move the first item to last in list =================="
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000035) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 1 AND 5 ORDER BY "position"
            # ~ (0.000049) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 5
            # ~ (0.000025) SELECT "id", "position" FROM "todos" WHERE "id" IN (1, 2, 3, 4, 5) ORDER BY "id"
            # ~ (0.000026) UPDATE "todos" SET "position" = 5 WHERE "id" = 1
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            
            # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
          it "should randomly move items around in the list" do 
            DataMapper.logger.debug "when using item.move(N) =>  should randomly move items around in the list =================="
            DataMapper.repository(:default) do |repos|
              items = Todo.all(:user => @u1, :order => [:position])
              
              items.each{ |item| item.move([5,2,4,3,1].index(item.id) + 1) }
              
              todo_list.should == [ [5,1], [2,2], [4,3], [3,4], [1,5] ]
            end
            DataMapper.logger.debug "when using item.move(N) =>  should randomly move items around in the list =================="
            
            # ~ (0.000028) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
            # ~ (0.000024) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000035) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 1 AND 5 ORDER BY "position"
            # ~ (0.000048) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 5
            # ~ (0.000025) SELECT "id", "position" FROM "todos" WHERE "id" IN (1, 2, 3, 4, 5) ORDER BY "id"
            # ~ (0.000026) UPDATE "todos" SET "position" = 5 WHERE "id" = 1
            
            # ~ (0.000025) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000035) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 1 AND 2 ORDER BY "position"
            # ~ (0.000045) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 2
            # ~ (0.000023) SELECT "id", "position" FROM "todos" WHERE "id" IN (2, 3) ORDER BY "id"
            # ~ (0.000028) UPDATE "todos" SET "position" = 2 WHERE "id" = 2
            
            # ~ (0.000026) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000037) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 1 AND 4 ORDER BY "position"
            # ~ (0.000050) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 4
            # ~ (0.000026) SELECT "id", "position" FROM "todos" WHERE "id" IN (2, 3, 4, 5) ORDER BY "id"
            # ~ (0.000027) UPDATE "todos" SET "position" = 4 WHERE "id" = 3
            
            # ~ (0.000026) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000038) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 2 AND 3 ORDER BY "position"
            # ~ (0.000047) UPDATE "todos" SET "position" = "position" + -1 WHERE "user_id" = 1 AND "position" BETWEEN 2 AND 3
            # ~ (0.000025) SELECT "id", "position" FROM "todos" WHERE "id" IN (4, 5) ORDER BY "id"
            # ~ (0.000027) UPDATE "todos" SET "position" = 3 WHERE "id" = 4
            
            # ~ (0.000027) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" DESC LIMIT 1
            # ~ (0.000037) SELECT "id" FROM "todos" WHERE "user_id" = 1 AND "id" IN (1, 2, 3, 4, 5) AND "position" BETWEEN 1 AND 2 ORDER BY "position"
            # ~ (0.000045) UPDATE "todos" SET "position" = "position" + 1 WHERE "user_id" = 1 AND "position" BETWEEN 1 AND 2
            # ~ (0.000025) SELECT "id", "position" FROM "todos" WHERE "id" IN (2, 5) ORDER BY "id"
            # ~ (0.000028) UPDATE "todos" SET "position" = 1 WHERE "id" = 5
            
            # ~ (0.000026) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
            
          end
          
        end #/ when using item.move(N) syntax
        
      end #/ Re-ordering
      
      describe "Movements" do 
        
        it "see the Instance Methods > #move specs above" do 
          # NOTE:: keeping this in the specs since this group was here previously, but it's now redundant. 
          # Should the tests be shared and used twice ?
          true.should == true
        end
        
      end #/ Movements
      
      # describe "Scoping" do 
      #   
      #   # see Instance Methods > #detach 
      #   
      #   describe "when deleting item" do 
      #     # see Workflows > CRUD > Deleting items
      #   end #/ when deleting item
      #   
      # end #/ Scoping
      
    end #/ Workflows
    
    
    describe "Twilight Zone" do 
      
      #  NOTE:: I do not understand the reasons for this behaviour, but perhaps it's how it should be.
      #  Why does having two variables pointing to the same row prevent it from being updated ?
      # 
      describe "accessing the same object via two variables" do 
        
        before do
          @todo5 = Todo.get(5)
        end
        
        it "should NOT update list" do 
          DataMapper.logger.debug "Twilight Zone => accessing the same object via two variables => should NOT update list"
          DataMapper.repository(:default) do |repos|
            item = Todo.get(5)
            item.position.should == 5
            item.position.should == @todo5.position
            
            # this should update the position in the DB
            @todo5.update(:position => 20)
            
            @todo5.position.should == 20
            todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            
            item.position.should == 5
            
          end
          DataMapper.logger.debug "Twilight Zone => accessing the same object via two variables => should NOT update list"
          
          # ~ (0.000019) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 5
          
          # ~ (0.000025) UPDATE "todos" SET "position" = 20 WHERE "id" = 5
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          
        end
        
        it "should update list when doing item.reload" do
          DataMapper.logger.debug "Twilight Zone => accessing the same object via two variables => should update list when doing item.reload"
          DataMapper.repository(:default) do |repos|
            item = Todo.get(5)
            item.position.should == 5
            item.position.should == @todo5.position
            
            # this should update the position in the DB
            @todo5.update(:position => 20)
            
            @todo5.position.should == 20
            
            todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 5] ]
            
            item.reload
            item.position.should == 20
            
            todo_list.should == [ [1, 1], [2, 2], [3, 3], [4, 4], [5, 20] ]
          end
          DataMapper.logger.debug "Twilight Zone => accessing the same object via two variables => should update list when doing item.reload"
          
          # ~ (0.000020) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "id" = 5
          
          # ~ (0.000026) UPDATE "todos" SET "position" = 20 WHERE "id" = 5
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position" # reload event ??
          # ~ (0.000023) SELECT "id", "title", "position", "user_id" FROM "todos" WHERE "user_id" = 1 ORDER BY "position"
          
        end
        
      end #/ accessing the same object via two variables
      
    end #/ Twilight Zone
    
  end
  
end
