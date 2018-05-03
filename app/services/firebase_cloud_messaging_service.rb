require 'fcm'
class FirebaseCloudMessagingService
  def self.trigger_alarm(receiver)
  	fcm = FCM.new(ENV['FIREBASE_CLOUD_MESSAGING_API_KEY'])
  	fcm.send([receiver.fcm_id], data: {message: 'Trigger Alarm'})
  end
end