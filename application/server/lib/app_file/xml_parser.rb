class AppFile::XmlParser
  def initialize(xml_file_path)
    xml_file = File.new(xml_file_path)
    @xml_document = REXML::Document.new(xml_file)
  end

  def extract_text(key:)
    elements = @xml_document.get_elements(key)
    elements[0].text unless elements.empty?
  end
end
