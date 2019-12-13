#
# Copyright (C) 2013 eNovance SAS <licensing@enovance.com>
#
# Author: Emilien Macchi <emilien.macchi@enovance.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# Tests for swift::proxy::bulk
#

require 'spec_helper'

describe 'swift::proxy::bulk' do

  describe "when using default parameters" do
    it { is_expected.to contain_swift_proxy_config('filter:bulk/use').with_value('egg:swift#bulk') }
    it { is_expected.to contain_swift_proxy_config('filter:bulk/max_containers_per_extraction').with_value('10000') }
    it { is_expected.to contain_swift_proxy_config('filter:bulk/max_failed_extractions').with_value('1000') }
    it { is_expected.to contain_swift_proxy_config('filter:bulk/max_deletes_per_request').with_value('10000') }
    it { is_expected.to contain_swift_proxy_config('filter:bulk/yield_frequency').with_value('60') }
  end

  describe "when overriding default parameters" do
    let :params do
      {
        :max_containers_per_extraction => 5000,
        :max_failed_extractions        => 500,
        :max_deletes_per_request       => 5000,
        :yield_frequency               => 10
      }
    end

    it { is_expected.to contain_swift_proxy_config('filter:bulk/use').with_value('egg:swift#bulk') }
    it { is_expected.to contain_swift_proxy_config('filter:bulk/max_containers_per_extraction').with_value('5000') }
    it { is_expected.to contain_swift_proxy_config('filter:bulk/max_failed_extractions').with_value('500') }
    it { is_expected.to contain_swift_proxy_config('filter:bulk/max_deletes_per_request').with_value('5000') }
    it { is_expected.to contain_swift_proxy_config('filter:bulk/yield_frequency').with_value('10') }
  end

end
