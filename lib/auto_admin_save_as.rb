module AutoAdminSaveAs
  def self.included receiver
    AutoAdmin::AutoAdminConfiguration.save_as.each do |format|
      require "save_as/#{format}"
    end
  end

  def save_as_blocks controller, block_handler, options
    AutoAdmin::AutoAdminConfiguration.save_as.each do |format|
      module_name = "AutoAdmin#{format.to_s.capitalize}".constantize
      module_name.save_as_proc controller, block_handler, options
    end
  end
end
