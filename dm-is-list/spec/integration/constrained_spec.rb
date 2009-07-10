## NB!! These tests fail.
# They are incorporated just to show the problem.  IF you know how to fix this issue, please do so.


require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

if HAS_MYSQL || HAS_SQLITE3 ||  HAS_POSTGRES
  
  # supported_by :all do
    
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
      property :position, Integer, :nullable => false, :unique_index => :position
      property :user_id, Integer, :unique_index => :position
      
      belongs_to :user
      
      is :list, :scope => [:user_id]
    end
    
    before :each do
      User.auto_migrate!
      Todo.auto_migrate!
      
      @u1 = User.create(:name => 'Johnny')
      @u2 = User.create(:name => 'Freddy')
    end
    
    describe "Todo" do 
      
      before(:each) do 
        @loop = 10
        @loop.times do |n|
          Todo.create(:user => @u1, :title => "Todo #{n+1}" )
        end
      end
      
      describe "should handle :unique_index => :position" do 
        
        it "should generate all in the correct order" do 
          DataMapper.repository(:default) do |repos|
            Todo.all.map{ |a| [a.id, a.position] }.should == (1..@loop).map { |n| [n,n] }
          end
        end
        
        it "should move items :higher in list" do 
          # DataMapper.logger.debug "should move Todo items higher =================="
          DataMapper.repository(:default) do |repos|
            Todo.get(2).move(:higher).should == true
            Todo.all.map{ |a| [a.id, a.position] }.should == [ [1, 2], [2, 1] ] + (3..@loop).map { |n| [n,n] }
          end
          # DataMapper.logger.debug "/should move Todo items higher =================="
        end
        
        it "should move items :lower in list" do 
          DataMapper.repository(:default) do |repos|
            Todo.get(9).move(:lower).should == true
            Todo.all.map{ |a| [a.id, a.position] }.should == (1..8).map { |n| [n,n] } + [ [9, 10], [10, 9] ] + (11..@loop).map { |n| [n,n] }
          end
        end
        
      end #/ should handle :unique_index => :position
      
    end #/ Todo
    
  end
  
  # end #/supported_by
  
end
