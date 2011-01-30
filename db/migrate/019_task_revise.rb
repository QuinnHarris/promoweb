class TaskRevise < ActiveRecord::Migration
  def self.up
    %w(customer order order_item).each do |type|
      add_column "#{type}_tasks", :user_id, :integer
      add_column "#{type}_tasks", :data, :text
      add_column "#{type}_tasks", :type, :string, :size => 32
      add_column "#{type}_tasks", :estimate, :boolean, :default => false, :null => false
      add_column "#{type}_tasks", :host, :string
    end
    
    execute("UPDATE customer_tasks SET type = 'CustomerInformationTask' FROM task_definitions " +
        "WHERE customer_tasks.task_definition_id = task_definitions.id AND task_definitions.alias = 'CInformation'")
    execute("ALTER TABLE customer_tasks ALTER type SET NOT NULL")
    
    { 'OAddItem' => 'AddItemOrderTask',
      'OItemNotes' => 'ItemNotesOrderTask',
      'OInformation' => 'InformationOrderTask',
      'OArtwork' => 'VisitArtworkOrderTask',
      'ORequest' => 'RequestOrderTask',
      'ORevised' => 'RevisedOrderTask',
      'OPayment' => 'PaymentInfoOrderTask',
      'OAknowledge' => 'AcknowledgeOrderTask',
      'OBilled' => 'FirstPaymentOrderTask',
      'OFinalPayment' => 'FinalPaymentOrderTask',
      'OArtReceived' => 'ArtReceivedOrderTask',
      'OArtDepartment' => 'ArtDepartmentOrderTask',
      'OArtPrepaired' => 'ArtPrepairedOrderTask',
      'OArtAknowledge' => 'ArtAcknowledgeOrderTask',
      'OArtSent' => 'ArtSentOrderTask',
      'OOwn' => 'OwnershipOrderTask' }.each do |src, dst|
      execute("UPDATE order_tasks SET type = '#{dst}' FROM task_definitions " +
        "WHERE order_tasks.task_definition_id = task_definitions.id AND task_definitions.alias = '#{src}'")
      end
    execute("ALTER TABLE order_tasks ALTER type SET NOT NULL")
      
    { 'IReady' => 'ReadyItemTask',
      'IOrderSent' => 'OrderSentItemTask',
      'IConfirm' => 'ConfirmItemTask',
      'IEstimated' => 'EstimatedItemTask',
      'ITracking' => 'ShipItemTask',
      'IReceived' => 'ReceivedItemTask',
      'IAccepted' => 'AcceptedItemTask' }.each do |src, dst|
      execute("UPDATE order_item_tasks SET type = '#{dst}' FROM task_definitions " +
        "WHERE order_item_tasks.task_definition_id = task_definitions.id AND task_definitions.alias = '#{src}'")
      end
    execute("ALTER TABLE order_item_tasks ALTER type SET NOT NULL")
    execute("DELETE FROM order_item_tasks WHERE type = 'ReadyItemTask'")
    
    %w(customer order order_item).each do |type|
      remove_column "#{type}_tasks", :task_definition_id
    end
    
    drop_table :task_definitions
  end

  def self.down
    raise IrreversibleMigration 
  end
end
