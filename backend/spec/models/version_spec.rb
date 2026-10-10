require "rails_helper"

RSpec.describe Version do
  describe "audit trail for employees and salary records" do
    it "records a create with every business field and who made it" do
      Current.actor = "hr.manager@acme.example"
      employee = create(:employee, full_name: "Asha Rao")

      version = described_class.find_by!(item: employee)
      expect(version.event).to eq("create")
      expect(version.whodunnit).to eq("hr.manager@acme.example")
      expect(version.object_changes["full_name"]).to eq([ nil, "Asha Rao" ])
      expect(version.object_changes.keys).not_to include("id", "created_at", "updated_at")
    end

    it "records an update with only the fields that changed, old and new" do
      employee = create(:employee, department: "Engineering")
      employee.update!(department: "Product")

      update = described_class.where(item: employee, event: "update").sole
      expect(update.object_changes).to eq("department" => %w[Engineering Product])
    end

    it "does not record a save that changed nothing" do
      employee = create(:employee)

      expect { employee.save! }.not_to change(described_class, :count)
    end

    it "keeps salary amounts exact in the log" do
      compensation = create(:compensation, amount: "123456.78")

      expect(described_class.find_by!(item: compensation).object_changes["amount"]).to eq([ nil, "123456.78" ])
    end

    it "leaves who-did-it empty when no actor is known" do
      employee = create(:employee)

      expect(described_class.find_by!(item: employee).whodunnit).to be_nil
    end

    it "lists an item's versions oldest first" do
      employee = create(:employee, job_title: "Analyst")
      employee.update!(job_title: "Senior Analyst")

      expect(employee.versions.map(&:event)).to eq(%w[create update])
    end
  end

  describe "append-only" do
    let(:version) { described_class.find_by!(item: create(:employee)) }

    it "cannot be edited once written" do
      expect { version.update!(whodunnit: "someone else") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "cannot be deleted through the model" do
      expect { version.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  it "rejects unknown events at the database level" do
    expect {
      described_class.insert_all!([ { item_type: "Employee", item_id: 1, event: "teleport", object_changes: {}, created_at: Time.current } ])
    }.to raise_error(ActiveRecord::StatementInvalid, /check/i)
  end
end
