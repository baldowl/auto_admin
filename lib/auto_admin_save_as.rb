# Quick hack to inject at runtime the export mechanism into the plugin's
# controller.
module AutoAdminSaveAs
  # We use this hook to +require+ the format modules requested by the user via
  # #save_as=.
  def self.included receiver
    AutoAdmin::AutoAdminConfiguration.save_as.each do |format|
      require "save_as/#{format}"
    end
  end

  # Inject into the plugin's controller a number of Proc objects to handle the
  # formats requested by the user. See one of the format module's
  # #save_as_proc method for details.
  def save_as_blocks controller, block_handler, options
    AutoAdmin::AutoAdminConfiguration.save_as.each do |format|
      module_name = "AutoAdmin#{format.to_s.capitalize}".constantize
      module_name.save_as_proc controller, block_handler, options
    end
  end
end
