// Package sender provides an API for mail sending operations
package sender

import (
	"fmt"

	"github.com/koding/bongo"
	"github.com/koding/logging"
	"github.com/sendgrid/sendgrid-go"
	"github.com/streadway/amqp"
)

// Emailer includes Send method to be implemented
type Emailer interface {
	Send(*Mail) error
}

// Controller holds required instances for processing events
type Controller struct {
	log     logging.Logger
	emailer Emailer
}

// SendGridMail includes the required Sendgrid struct
type SendGridMail struct {
	Sendgrid *sendgrid.SGClient
}

// New Creates a new controller for mail worker
func New(log logging.Logger, em Emailer) *Controller {
	return &Controller{
		log:     log,
		emailer: em,
	}
}

// Send gets the mail struct that includes the message
// when we call this function, it sends the given mail to the
// address that will be sent.
func Send(m *Mail) error {
	return bongo.B.PublishEvent("send", m)
}

// Process creates and sets the message that will be sent,
// and sends the message according to the mail adress
// its a helper method to send message
func (c *Controller) Process(m *Mail) error {
	return c.emailer.Send(m)
}

// DefaultErrHandler controls the errors, return false if an error occurred
func (c *Controller) DefaultErrHandler(delivery amqp.Delivery, err error) bool {
	c.log.Error("an error occurred %+v", err.Error())
	delivery.Nack(false, true)

	return false
}

// Send implements Emailer interface
func (sg *SendGridMail) Send(m *Mail) error {
	message := sendgrid.NewMail()

	if err := message.AddTo(m.To); err != nil {
		return err
	}

	if err := message.SetFrom("mail@koding.com"); err != nil {
		return err
	}

	if m.From != "" {
		message.SetFrom(m.From)
	}

	message.SetText(m.Text)
	message.SetHTML(m.HTML)
	message.SetSubject(m.Subject)
	message.SetFromName(m.FromName)
	if m.ReplyTo != "" {
		if err := message.SetReplyTo(m.ReplyTo); err != nil {
			return err
		}
	}

	if err := sg.Sendgrid.Send(message); err != nil {
		return fmt.Errorf("an error occurred while sending email error as %+v ", err.Error())
	}

	return nil
}
