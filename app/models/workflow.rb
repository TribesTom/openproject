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

class Workflow < ActiveRecord::Base
  belongs_to :role
  belongs_to :old_status, class_name: 'Status', foreign_key: 'old_status_id'
  belongs_to :new_status, class_name: 'Status', foreign_key: 'new_status_id'

  validates_presence_of :role, :old_status, :new_status

  # Returns workflow transitions count by type and role
  def self.count_by_type_and_role
    counts = connection.select_all("SELECT role_id, type_id, count(id) AS c FROM #{Workflow.table_name} GROUP BY role_id, type_id")
    roles = Role.order('builtin, position')
    types = ::Type.order('position')

    result = []
    types.each do |type|
      t = []
      roles.each do |role|
        row = counts.detect { |c| c['role_id'].to_s == role.id.to_s && c['type_id'].to_s == type.id.to_s }
        t << [role, (row.nil? ? 0 : row['c'].to_i)]
      end
      result << [type, t]
    end

    result
  end

  # Find potential statuses the user could be allowed to switch issues to
  def self.available_statuses(project, user = User.current)
    Workflow.includes(:new_status)
      .where(role_id: user.roles_for_project(project).map(&:id))
      .map(&:new_status)
      .compact
      .uniq
      .sort
  end

  # Copies workflows from source to targets
  def self.copy(source_type, source_role, target_types, target_roles)
    unless source_type.is_a?(::Type) || source_role.is_a?(Role)
      raise ArgumentError.new('source_type or source_role must be specified')
    end

    target_types = Array(target_types)
    target_types = ::Type.all if target_types.empty?

    target_roles = Array(target_roles)
    target_roles = Role.all if target_roles.empty?

    target_types.each do |target_type|
      target_roles.each do |target_role|
        copy_one(source_type || target_type,
                 source_role || target_role,
                 target_type,
                 target_role)
      end
    end
  end

  # Copies a single set of workflows from source to target
  def self.copy_one(source_type, source_role, target_type, target_role)
    unless source_type.is_a?(::Type) && !source_type.new_record? &&
           source_role.is_a?(Role) && !source_role.new_record? &&
           target_type.is_a?(::Type) && !target_type.new_record? &&
           target_role.is_a?(Role) && !target_role.new_record?

      raise ArgumentError.new('arguments can not be nil or unsaved objects')
    end

    if source_type == target_type && source_role == target_role
      false
    else
      transaction do
        delete_all type_id: target_type.id, role_id: target_role.id
        connection.insert <<-SQL
          INSERT INTO #{Workflow.table_name} (type_id, role_id, old_status_id, new_status_id, author, assignee)
          SELECT #{target_type.id}, #{target_role.id}, old_status_id, new_status_id, author, assignee
          FROM #{Workflow.table_name}
          WHERE type_id = #{source_type.id} AND role_id = #{source_role.id}
        SQL
      end
      true
    end
  end
end
