require 'faster_csv'

module AutoAdminCsv
  def self.save_as_proc controller, block_handler, options
    model = controller.model
    block_handler.csv do
      @objects = model.find(:all, options)
      export_into_csv_excel(controller, model, @objects)
    end
  end

  def self.export_into_csv_excel(controller, model, collection)
    content_type = tweak_csv_excel_content_type controller.request
    csv_content = FasterCSV.generate do |csv|
      csv << model.columns.map {|col| col.human_name}
      collection.each do |o|
        csv << model.columns.map {|col| o.send(col.name.to_sym)}
      end
    end
    controller.send(:send_data, csv_content, :type => content_type,
      :filename => "#{model.human_name.downcase}.csv")
  end

  def self.tweak_csv_excel_content_type request
    if request.respond_to?(:user_agent)
      request.user_agent =~ /windows/i ? 'application/vnd.ms-excel' : 'text/csv'
    else
      'text/csv'
    end
  end
end
