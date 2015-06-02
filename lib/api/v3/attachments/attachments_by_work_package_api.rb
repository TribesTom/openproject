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

require 'api/v3/attachments/attachment_collection_representer'

module API
  module V3
    module Attachments
      class AttachmentsByWorkPackageAPI < ::API::OpenProjectAPI
        resources :attachments do
          helpers do
            def make_uploaded_file(file, file_name)
              uploaded_file = Rack::Multipart::UploadedFile.new file[:tempfile].path,
                                                                file[:type],
                                                                true
              # I wish I could set the file name in a better way *sigh*
              uploaded_file.instance_variable_set(:@original_filename, file_name)
              uploaded_file
            end

            def parse_metadata(json)
              return nil unless json

              # FIXME: we should be using the attachment representer to parse the metadata
              # We can't because it relies on the underlying :file being magical (e.g. for fileName)
              begin
                parsed_json = ::JSON.parse(json)
              rescue ::JSON::ParserError
                raise ::API::Errors::InvalidRequestBody.new(I18n.t('api_v3.errors.invalid_json'))
              end

              file_name = parsed_json['fileName']

              unless file_name
                raise ::API::Errors::Validation.new(
                        "fileName #{I18n.t('activerecord.errors.messages.blank')}.")
              end

              {
                file_name: file_name,
                description: (parsed_json['description'] || {})['raw'] || ''
              }
            end
          end

          get do
            self_path = api_v3_paths.attachments_by_work_package(@work_package.id)
            attachments = @work_package.attachments
            AttachmentCollectionRepresenter.new(attachments,
                                                attachments.count,
                                                self_path)
          end

          post do
            authorize(:edit_work_packages, context: @work_package.project)

            metadata = parse_metadata params[:metadata]
            file = params[:file]

            unless metadata && file
              raise ::API::Errors::InvalidRequestBody.new(
                      I18n.t('api_v3.errors.multipart_body_error'))
            end

            uploaded_file = make_uploaded_file file, metadata[:file_name]
            attachment = Attachment.new(file: uploaded_file,
                                        container: @work_package,
                                        description: metadata[:description],
                                        author: current_user)

            unless attachment.save
              raise ::API::Errors::ErrorBase.create(attachment.errors.dup)
            end

            ::API::V3::Attachments::AttachmentRepresenter.new(attachment)
          end
        end
      end
    end
  end
end
