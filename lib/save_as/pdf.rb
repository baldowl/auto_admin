Mime::Type.register 'application/pdf', :pdf
require 'pdf/simpletable'

module AutoAdminPdf
  def self.save_as_proc controller, block_handler, options
    model = controller.model
    block_handler.pdf do
      @objects = model.find(:all, options)
      export_into_pdf(controller, model, @objects)
    end
  end

  def self.export_into_pdf(controller, model, collection)
    pdf = PDF::Writer.new :paper => 'A4', :orientation => :landscape
    pdf.select_font "Times-Roman"

    PDF::SimpleTable.new do |table|
      table.title = "<b>#{model.human_name.titleize}'s records</b>"
      table.title_font_size = 20
      table.title_gap = 10
      table.bold_headings = true
      table.position = :center
      table.width = pdf.margin_width
      table.column_order = model.column_names
      table.data = collection.map {|r| r.attributes}
      table.render_on(pdf)
    end

    controller.send(:send_data, pdf.render, :type => 'application/pdf',
      :filename => "#{model.human_name.downcase}.pdf")
  end
end
