#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2014 the OpenProject Foundation (OPF)
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

Feature: Paginated work packages index list

  Background:
    Given we paginate after 3 items
    And there is 1 project with the following:
      | identifier | project1 |
      | name       | project1 |
    And the project "project1" has the following types:
      | name | position |
      | Bug  |     1    |
    And there is 1 user with the following:
      | login      | bob      |
    And there is a role "member"
    And the role "member" may have the following rights:
      | view_work_packages |
    And the user "bob" is a "member" in the project "project1"
    And the user "bob" has 4 issues with the following:
      | subject    | Issuesubject |
    And I am already logged in as "bob"

  @javascript
  Scenario: Pagination within a project
    When I go to the work packages index page of the project "project1"
    Then I should see 3 issues
    When I follow "2" within ".pagination-container .pagination"
    Then I should be on the work packages index page of the project "project1"
    And I should see 1 issue

  @javascript
  Scenario: Pagination outside a project
    When I go to the global index page of work packages
    Then I should see 3 issues
    When I follow "2" within ".pagination-container .pagination"
    Then I should be on the global index page of work packages
    And I should see 1 issue

  @javascript
  Scenario: Changing issues per page
    When I go to the work packages index page of the project "project1"
    Then I follow "2" within ".pagination-container .pagination"
    Then I should see 1 issue
    Then I follow "100" within ".items-per-page-container .pagination"
    Then I should see 4 issues
