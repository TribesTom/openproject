#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++
# Adding ISSEP preformated PDF

# Returns a PDF string of a list of work_packages

require 'rfpdf/fpdf'
require 'tcpdf'

module WorkPackage::PdfExporter
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::NumberHelper
 
 def pdfCORDI(work_packages, project, query, results, options = {})
    if  current_language.to_s.downcase == 'ko'    ||
        current_language.to_s.downcase == 'ja'    ||
        current_language.to_s.downcase == 'zh'    ||
        current_language.to_s.downcase == 'zh-tw' ||
        current_language.to_s.downcase == 'th'
      pdf = IFPDF.new(current_language)
    else
      pdf = ITCPDF.new(current_language)
    end
    title = query.new_record? ? l(:label_work_package_plural) : query.name
    title = "#{project} - #{title}" if project
    pdf.SetTitle(title)
    pdf.alias_nb_pages
    pdf.footer_date = format_date(Date.today)
#   pdf.SetFooter("0 = Permanent, 1-5 : Urgent - Long Terme ")
    pdf.SetAutoPageBreak(false)
    pdf.AddPage('L')

    # Landscape A4 = 210 x 297 mm
    page_height = 210
    page_width = 297
    right_margin = 10
    bottom_margin = 20
    row_height = 5

    # column widths
    table_width = page_width - right_margin - 10  # fixed left margin
    col_width = [60,40,30,107,40]
#    unless query.columns.empty?
#		col_width = WhichWidthColumnCordi(query)
 #     col_width = query.columns.map do |c|
 #       (c.name == :subject || (c.is_a?(QueryCustomFieldColumn) && ['string', 'text'].include?(c.custom_field.field_format))) ? 4.0 : 1.0
 #     end
 #     ratio = 100 * table_width / col_width.reduce(:+)
#      if ratio > 100
#	col_width = col_width.map { |w| (w * ratio) / 100 }
#      else
#	ratio = 100
#	end
 #   end

    # title
    pdf.SetFontStyle('B', 11)
    pdf.RDMCell(190, 10, title)
    pdf.Ln
    # info

   # pdf.SetFontStyle('B', 11)
   # pdf.RDMCell(190, 10, "ratio : " + ratio.to_s + " table width : " + table_width.to_s + " reduce : " + col_width.reduce(:+).to_s)
   # pdf.Ln
    


    # headers
    pdf.SetFontStyle('B', 8)
    pdf.SetFillColor(230, 230, 230)
    #query.columns.each_with_index do |column, i|
    pdf.RDMCell(col_width[0], row_height, "Décision",1, 0, 'L', 1)
    pdf.RDMCell(col_width[1], row_height, "Responsable Décision",1, 0, 'L', 1)
    pdf.RDMCell(col_width[2], row_height, "Date d\'applisaction", 1, 0, 'L', 1)
    pdf.RDMCell(col_width[3], row_height, "Tache", 1, 0, 'L', 1)
    pdf.RDMCell(col_width[4], row_height, "Responsable Tache", 1, 0, 'L', 1)
    #end
    pdf.Ln

    # rows
    pdf.SetFontStyle('', 8)
    pdf.SetFillColor(255, 255, 255)
    previous_group = false
    work_packages.each do |work_package|
      if work_package.type_id == 8
	
      # fetch row value for décision
	cv = work_package.custom_values.detect { |v| v.custom_field_id == 16 }

      	col_values = [work_package.send("subject").to_s,work_package.send("responsible").to_s,show_value(cv),"",""]

      	Render(pdf,col_values,col_width,row_height,page_height,bottom_margin)
      	work_packages.each do |child_package|
      	  if child_package.parent_id == work_package.id 
	    col_values = ["","","",child_package.send("subject").to_s,child_package.send("responsible").to_s]
	    Render(pdf,col_values,col_width,row_height,page_height,bottom_margin)
          end
        end
          
      end
    end

    if work_packages.size == Setting.work_packages_export_limit.to_i
      pdf.SetFontStyle('B', 10)
      pdf.RDMCell(0, row_height, '...')
    end
    pdf.Output
  end

def Render(pdf,col_values,col_width,row_height,page_height,bottom_margin)
      # render it off-page to find the max height used
      base_x = pdf.GetX
      base_y = pdf.GetY
      pdf.SetY(2 * page_height)
      max_height = pdf_write_cells(pdf, col_values, col_width, row_height)
      description_height = 0


      pdf.SetXY(base_x, base_y)

      # make new page if it doesn't fit on the current one
      space_left = page_height - base_y - bottom_margin
      if max_height + description_height > space_left
        pdf.AddPage('L')
        base_x = pdf.GetX
        base_y = pdf.GetY
      end

      pdf_write_cells(pdf, col_values, col_width, row_height)
      pdf_draw_borders(pdf, base_x, base_y, base_y + max_height, col_width)

      # description

      pdf.SetY(base_y + max_height)
end


def OneValue(column)
  s = if column.is_a?(QueryCustomFieldColumn)
        cv = work_package.custom_values.detect { |v| v.custom_field_id == column.custom_field.id }
        show_value(cv)
      else
        value = work_package.send(column.name)
        if value.is_a?(Date)
          format_date(value)
        elsif value.is_a?(Time)
          format_time(value)
        else
          value
        end
      end
  s.to_s
end


def WhichWidthColumnCordi(query)
 # project,priority,subject,responsible,due_date,done_ratio,cf_9,cf_10,status,Description
	width = Hash[
		"object" => 60,
		"subject" => 60,
		"priority" => 15,
		"responsible" => 25,
		"done_ratio" => 10,
		"due_date" => 25,
		"cf_9" => 20,
		"cf_10" => 20,
		"status" => 15,
		"Description" => 70,
		"id" => 10,
		"project" => 20,
		"start_date" =>22,
		"cf_13" => 17,
		"cf_14" => 10
		]
	width.default = 40
      col = Array.new
      query.columns.each_with_index do |column, i|
      col[i]=width[column.name.to_s]
    end	
    col		
  end

def WhichColor(status)

	availableColor = {
		"non programmé" => [255,51,51],
		"programmé" => [255,153,51],
		"terminé" => [153,255,51]
		}
	availableColor.default = [255,255,255]
	availableColor[status]
  end
end
