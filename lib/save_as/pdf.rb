Mime::Type.register 'application/pdf', :pdf
require 'pdf/simpletable'

# Simple module to save data in PDF format.
module AutoAdminPdf
  # Add a block into the plugin's controller's +respond_to+ construct, passing
  # down the stream the +options+ set by users via the web interface.
  def self.save_as_proc controller, block_handler, options
    model = controller.model
    block_handler.pdf do
      @objects = model.find(:all, options)
      export_into_pdf(controller, model, @objects)
    end
  end

  # Using PDF::Writer in a rather inflexbile way we dump +collection+ into a
  # single PDF stream.
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
