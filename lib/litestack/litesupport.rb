require 'sqlite3'

module Litesupport

  # cache the environment we are running in
  # it is an error to change the environment for a process 
  # or for a child forked from that process
  def self.environment
    @env ||= detect_environment
  end
  
  # identify which environment we are running in
  # we currently support :fiber, :polyphony, :iodine & :threaded
  # in the future we might want to expand to other environments
  def self.detect_environment
    return :fiber if Fiber.scheduler 
    return :polyphony if defined? Polyphony
    return :iodine if defined? Iodine
    return :threaded # fall back for all other environments
  end
  
  # spawn a new execution context
  def self.spawn(&block)
    if self.environment == :fiber
      Fiber.schedule(&block)
    elsif self.environment == :polyphony
      spin(&block)
    elsif self.environment == :threaded or self.environment == :iodine
      Thread.new(&block)
    end
    # we should never reach here
  end
  
  # switch the execution context to allow others to run
  def self.switch
    if self.environment == :fiber
      Fiber.scheduler.yield
    elsif self.environment == :polyphony
      Fiber.current.schedule
      Thread.current.switch_fiber
    else
      # do nothing in case of thread, switching will auto-happen
    end   
  end
  
  # mutex initialization
  def self.mutex
    # a single mutex per process (is that ok?)
    @@mutex ||= Mutex.new
  end
  
  # bold assumption, we will only synchronize threaded code
  # if some code explicitly wants to synchronize a fiber
  # they must send (true) as a parameter to this method
  # else it is a no-op for fibers
  def self.synchronize(fiber_sync = false, &block)
    if self.environment == :fiber or self.environment == :polyphony
      yield # do nothing, just run the block as is
    else
      self.mutex.synchronize(&block)
    end
  end
  
  # common db object options
  def self.create_db(path)
    db = SQLite3::Database.new(path)
    db.busy_handler{ sleep 0.001 }
    db.journal_mode = "WAL"
    db
  end
  
end  